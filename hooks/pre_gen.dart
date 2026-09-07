import 'dart:convert';
import 'dart:io';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;

Future<void> run(HookContext context) async {
  final targetDir = Directory.current;
  context.logger.info('');
  context.logger.info('🔍 Analyzing project at ${targetDir.path}...');

  // 1. Look for all package.json files in targetDir and subfolders
  final packageJsonFiles = findPackageJsonFiles(targetDir);

  if (packageJsonFiles.isEmpty) {
    context.logger.err(
      '❌ No package.json found in ${targetDir.path} or any subdirectories.\n'
      '   Please run this brick inside a JavaScript/TypeScript/Bun project.',
    );
    throw Exception('No package.json found in project directory.');
  }

  // 2. Check if the project is a Bun.js project
  final isBun = isBunProject(targetDir, packageJsonFiles);
  if (isBun) {
    context.logger.info('⚡ Detected Bun.js project.');
  } else {
    context.logger.info('📦 Detected JavaScript/TypeScript project.');
  }

  // 3. Format package.json choices (relative paths)
  final packageJsonChoices = packageJsonFiles.map((file) {
    final rel =
        p.relative(file.path, from: targetDir.path).replaceAll('\\', '/');
    return rel.startsWith('.') ? rel : './$rel';
  }).toList();

  // Sort so root package.json is first if present, then alphabetical
  packageJsonChoices.sort((a, b) {
    if (a == './package.json') return -1;
    if (b == './package.json') return 1;
    return a.compareTo(b);
  });

  // Prompt user to select package.json
  final selectedPackageRelative = chooseOption<String>(
    logger: context.logger,
    message:
        'Select the package.json where the Biome dependency should be added:',
    choices: packageJsonChoices,
    defaultValue: packageJsonChoices.first,
  );

  final selectedPackageFile = File(
    p.normalize(p.join(targetDir.path, selectedPackageRelative)),
  );
  final selectedPackageDir = selectedPackageFile.parent;

  // 4. Infer package manager based on lockfiles and environment
  final inferredPm = inferPackageManager(
    targetDir: targetDir,
    selectedPackageDir: selectedPackageDir,
    packageFile: selectedPackageFile,
    isBun: isBun,
  );

  context.logger.info('💡 Inferred package manager: $inferredPm');

  // 5. Prompt user for package manager
  final selectedPm = chooseOption<String>(
    logger: context.logger,
    message: 'Select the package manager to be used:',
    choices: const ['bun', 'pnpm', 'npm', 'yarn'],
    defaultValue: inferredPm,
  );

  // 6. Prompt to add scripts to package.json
  final addScripts = confirmOption(
    logger: context.logger,
    message: 'Add Biome script ("check") to package.json?',
    defaultValue: true,
  );

  // 7. If package.json is in a subfolder, ask where to place biome.json
  var placeBiomeInSubfolder = false;
  final isSubfolder = selectedPackageRelative != './package.json' &&
      selectedPackageRelative != 'package.json';
  if (isSubfolder) {
    final subfolderRel = p
        .relative(selectedPackageDir.path, from: targetDir.path)
        .replaceAll('\\', '/');
    final configLocationChoice = chooseOption<String>(
      logger: context.logger,
      message: 'Where would you like to place biome.json?',
      choices: [
        'Project root (./biome.json)',
        'Selected package directory (./$subfolderRel/biome.json)',
      ],
      defaultValue: 'Project root (./biome.json)',
    );
    placeBiomeInSubfolder = configLocationChoice.startsWith('Selected package');
  }

  // 8. Prompt to run package manager install
  final shouldInstall = confirmOption(
    logger: context.logger,
    message: 'Run "$selectedPm" to install @biomejs/biome now?',
    defaultValue: true,
  );

  // 9. Update the chosen package.json with @biomejs/biome and scripts
  await updatePackageJson(
    packageFile: selectedPackageFile,
    addScripts: addScripts,
    logger: context.logger,
  );

  // 10. Pass variables to context for template generation and post_gen
  final hasGit = isGitRepository(targetDir);
  context.vars['has_git'] = hasGit;
  context.vars['is_bun'] = isBun;
  context.vars['package_manager'] = selectedPm;
  context.vars['selected_package_json'] = selectedPackageRelative;
  context.vars['selected_package_dir'] = p
      .relative(selectedPackageDir.path, from: targetDir.path)
      .replaceAll('\\', '/');
  context.vars['place_biome_in_subfolder'] = placeBiomeInSubfolder;
  context.vars['should_install'] = shouldInstall;
}

T chooseOption<T extends Object?>({
  required Logger logger,
  required String message,
  required List<T> choices,
  required T defaultValue,
  String Function(T)? display,
}) {
  if (!stdin.hasTerminal) {
    final defaultLabel = display != null ? display(defaultValue) : defaultValue;
    logger.info('$message [Non-interactive: using $defaultLabel]');
    return defaultValue;
  }
  try {
    return logger.chooseOne(
      message,
      choices: choices,
      defaultValue: defaultValue,
      display: display,
    );
  } catch (_) {
    return defaultValue;
  }
}

bool confirmOption({
  required Logger logger,
  required String message,
  required bool defaultValue,
}) {
  if (!stdin.hasTerminal) {
    logger.info('$message [Non-interactive: using $defaultValue]');
    return defaultValue;
  }
  try {
    return logger.confirm(message, defaultValue: defaultValue);
  } catch (_) {
    return defaultValue;
  }
}

/// Checks whether the target directory (defaults to [Directory.current]) is a Git repository.
bool isGitRepository([Directory? directory]) {
  final target = directory ?? Directory.current;
  return Directory(p.join(target.path, '.git')).existsSync();
}

const ignoredDirectories = {
  'node_modules',
  '.git',
  '.turbo',
  '.next',
  '.nuxt',
  'dist',
  'build',
  'out',
  '.cache',
  '.dart_tool',
  '.gemini',
  'coverage',
  '.vscode',
  '.idea',
  'vendor',
  '.mason',
};

List<File> findPackageJsonFiles(Directory rootDir) {
  final results = <File>[];

  void scan(Directory current) {
    List<FileSystemEntity> entities;
    try {
      entities = current.listSync(followLinks: false);
    } catch (_) {
      return;
    }

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (name.startsWith('.') ||
            ignoredDirectories.contains(name.toLowerCase())) {
          continue;
        }
        scan(entity);
      } else if (entity is File) {
        if (name.toLowerCase() == 'package.json') {
          results.add(entity);
        }
      }
    }
  }

  scan(rootDir);
  return results;
}

bool isBunProject(Directory targetDir, List<File> packageFiles) {
  // Check for bun lockfile or config in targetDir
  if (File(p.join(targetDir.path, 'bun.lock')).existsSync() ||
      File(p.join(targetDir.path, 'bun.lockb')).existsSync() ||
      File(p.join(targetDir.path, 'bunfig.toml')).existsSync()) {
    return true;
  }

  // Check in all package directories for bun lockfiles
  for (final pkgFile in packageFiles) {
    final parent = pkgFile.parent;
    if (File(p.join(parent.path, 'bun.lock')).existsSync() ||
        File(p.join(parent.path, 'bun.lockb')).existsSync() ||
        File(p.join(parent.path, 'bunfig.toml')).existsSync()) {
      return true;
    }

    try {
      final jsonMap =
          json.decode(pkgFile.readAsStringSync()) as Map<String, dynamic>;
      final pm = (jsonMap['packageManager'] as String?)?.toLowerCase();
      if (pm != null && pm.startsWith('bun')) return true;

      final devDeps = (jsonMap['devDependencies'] as Map?) ?? {};
      final deps = (jsonMap['dependencies'] as Map?) ?? {};
      if (devDeps.containsKey('@types/bun') ||
          devDeps.containsKey('bun-types') ||
          deps.containsKey('bun')) {
        return true;
      }
    } catch (_) {}
  }

  return false;
}

String inferPackageManager({
  required Directory targetDir,
  required Directory selectedPackageDir,
  required File packageFile,
  required bool isBun,
}) {
  // Check selected package directory first, then root target directory
  final dirsToCheck = <Directory>[
    selectedPackageDir,
    if (selectedPackageDir.path != targetDir.path) targetDir,
  ];

  for (final dir in dirsToCheck) {
    if (File(p.join(dir.path, 'bun.lock')).existsSync() ||
        File(p.join(dir.path, 'bun.lockb')).existsSync() ||
        File(p.join(dir.path, 'bunfig.toml')).existsSync()) {
      return 'bun';
    }
    if (File(p.join(dir.path, 'pnpm-lock.yaml')).existsSync()) {
      return 'pnpm';
    }
    if (File(p.join(dir.path, 'yarn.lock')).existsSync()) {
      return 'yarn';
    }
    if (File(p.join(dir.path, 'package-lock.json')).existsSync()) {
      return 'npm';
    }
  }

  // Check packageManager field in selected package.json
  try {
    final jsonMap =
        json.decode(packageFile.readAsStringSync()) as Map<String, dynamic>;
    final pm = (jsonMap['packageManager'] as String?)?.toLowerCase();
    if (pm != null) {
      if (pm.startsWith('bun')) return 'bun';
      if (pm.startsWith('pnpm')) return 'pnpm';
      if (pm.startsWith('yarn')) return 'yarn';
      if (pm.startsWith('npm')) return 'npm';
    }
  } catch (_) {}

  // If bun project was detected elsewhere
  if (isBun) return 'bun';

  // Default fallback
  return 'npm';
}

Future<void> updatePackageJson({
  required File packageFile,
  required bool addScripts,
  required Logger logger,
}) async {
  final content = await packageFile.readAsString();
  Map<String, dynamic> jsonMap;
  try {
    jsonMap = json.decode(content) as Map<String, dynamic>;
  } catch (e) {
    logger.err('Failed to parse JSON in ${packageFile.path}: $e');
    return;
  }

  // Add @biomejs/biome to devDependencies
  final devDependencies =
      (jsonMap['devDependencies'] as Map<String, dynamic>?) != null
          ? Map<String, dynamic>.from(jsonMap['devDependencies'] as Map)
          : <String, dynamic>{};

  devDependencies['@biomejs/biome'] = '^1.9.4';
  jsonMap['devDependencies'] = devDependencies;

  if (addScripts) {
    final scripts = (jsonMap['scripts'] as Map<String, dynamic>?) != null
        ? Map<String, dynamic>.from(jsonMap['scripts'] as Map)
        : <String, dynamic>{};

    scripts['check:fix'] ??= 'biome check --write .';
    jsonMap['scripts'] = scripts;
  }

  final updatedContent = const JsonEncoder.withIndent('  ').convert(jsonMap);
  await packageFile.writeAsString('$updatedContent\n');

  final displayPath = p
      .relative(packageFile.path, from: Directory.current.path)
      .replaceAll('\\', '/');
  logger.success('Added @biomejs/biome to ./$displayPath devDependencies');
}
