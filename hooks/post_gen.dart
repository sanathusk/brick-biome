import 'dart:io';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;

Future<void> run(HookContext context) async {
  final targetDir = Directory.current;
  final shouldInstall = context.vars['should_install'] as bool? ?? false;
  final packageManager = context.vars['package_manager'] as String? ?? 'npm';
  final selectedPackageDirRel = context.vars['selected_package_dir'] as String? ?? '';
  final placeBiomeInSubfolder = context.vars['place_biome_in_subfolder'] as bool? ?? false;

  final packageWorkingDir = selectedPackageDirRel.isEmpty || selectedPackageDirRel == '.'
      ? targetDir
      : Directory(p.normalize(p.join(targetDir.path, selectedPackageDirRel)));


  // 1. If user selected to place biome.json in package subfolder, move it from targetDir
  if (placeBiomeInSubfolder && selectedPackageDirRel.isNotEmpty && selectedPackageDirRel != '.') {
    relocateBiomeJson(
      targetDir: targetDir,
      destinationDir: packageWorkingDir,
      logger: context.logger,
    );
  }

  // 2. Install dependencies if user requested
  if (shouldInstall) {
    final relPath = p.relative(packageWorkingDir.path, from: targetDir.path).replaceAll('\\', '/');
    final displayDir = relPath.isEmpty ? '.' : './$relPath';
    final progress = context.logger.progress(
      'Installing dependencies with $packageManager in $displayDir...',
    );

    List<String> commandArgs;
    switch (packageManager) {
      case 'bun':
        commandArgs = ['add', '-d', '@biomejs/biome'];
        break;
      case 'pnpm':
        commandArgs = ['add', '-D', '@biomejs/biome'];
        break;
      case 'yarn':
        commandArgs = ['add', '-D', '@biomejs/biome'];
        break;
      case 'npm':
      default:
        commandArgs = ['install', '--save-dev', '@biomejs/biome'];
        break;
    }

    try {
      final result = await Process.run(
        packageManager,
        commandArgs,
        runInShell: true,
        workingDirectory: packageWorkingDir.path,
      );

      if (result.exitCode == 0) {
        progress.complete('Installed @biomejs/biome successfully!');
      } else {
        progress.fail('Failed to install dependencies with $packageManager.');
        if (result.stderr.toString().trim().isNotEmpty) {
          context.logger.err(result.stderr.toString().trim());
        }
        context.logger.warn(
          '💡 You can manually install the dependency by running:\n'
          '   cd "$selectedPackageDirRel" && $packageManager ${commandArgs.join(' ')}',
        );
      }
    } catch (e) {
      progress.fail('Could not execute $packageManager: $e');
      context.logger.warn(
        '💡 Ensure $packageManager is installed on your system. You can install manually with:\n'
        '   cd "$selectedPackageDirRel" && $packageManager ${commandArgs.join(' ')}',
      );
    }
  }

  context.logger.info('');
  context.logger.success('✨ Biome setup completed successfully!');
  context.logger.info('');
  context.logger.info('Next steps:');
  context.logger.info('  • Check code:    $packageManager run check');
  context.logger.info('  • Format code:   $packageManager run format');
  context.logger.info('  • Lint code:     $packageManager run lint');
}

/// Relocates the generated biome.json from [targetDir] to [destinationDir] if needed.
void relocateBiomeJson({
  required Directory targetDir,
  required Directory destinationDir,
  required Logger logger,
}) {
  final rootBiomeFile = File(p.join(targetDir.path, 'biome.json'));
  final destBiomeFile = File(p.join(destinationDir.path, 'biome.json'));

  if (rootBiomeFile.existsSync() && rootBiomeFile.path != destBiomeFile.path) {
    if (!destinationDir.existsSync()) {
      destinationDir.createSync(recursive: true);
    }
    rootBiomeFile.renameSync(destBiomeFile.path);
    logger.info(
      'Moved biome.json to ${p.relative(destBiomeFile.path, from: targetDir.path)}',
    );
  }
}
