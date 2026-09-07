import 'dart:convert';
import 'dart:io';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../pre_gen.dart';

void main() {
  group('Biome Brick pre_gen hook', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('biome_pre_gen_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('isGitRepository detects .git folder', () {
      expect(isGitRepository(tempDir), isFalse);
      Directory(p.join(tempDir.path, '.git')).createSync();
      expect(isGitRepository(tempDir), isTrue);
    });

    test('findPackageJsonFiles finds root and nested package.json', () {
      final rootPkg = File(p.join(tempDir.path, 'package.json'))..createSync();
      final subDir = Directory(p.join(tempDir.path, 'apps', 'web'))..createSync(recursive: true);
      final subPkg = File(p.join(subDir.path, 'package.json'))..createSync();

      // Ignored dirs
      final nodeModules = Directory(p.join(tempDir.path, 'node_modules', 'foo'))..createSync(recursive: true);
      File(p.join(nodeModules.path, 'package.json')).createSync();
      final gitDir = Directory(p.join(tempDir.path, '.git'))..createSync(recursive: true);
      File(p.join(gitDir.path, 'package.json')).createSync();

      final files = findPackageJsonFiles(tempDir);
      expect(files.map((f) => p.normalize(f.path)), contains(p.normalize(rootPkg.path)));
      expect(files.map((f) => p.normalize(f.path)), contains(p.normalize(subPkg.path)));
      expect(files.length, equals(2));
    });

    test('isBunProject detects bun.lock, bun.lockb, and bunfig.toml', () {
      final pkg = File(p.join(tempDir.path, 'package.json'))..writeAsStringSync('{}');
      expect(isBunProject(tempDir, [pkg]), isFalse);

      File(p.join(tempDir.path, 'bun.lock')).createSync();
      expect(isBunProject(tempDir, [pkg]), isTrue);
    });

    test('isBunProject detects packageManager field with bun', () {
      final pkg = File(p.join(tempDir.path, 'package.json'))
        ..writeAsStringSync(json.encode({'packageManager': 'bun@1.2.0'}));
      expect(isBunProject(tempDir, [pkg]), isTrue);
    });

    test('inferPackageManager detects bun when bun.lock is present', () {
      final pkg = File(p.join(tempDir.path, 'package.json'))..writeAsStringSync('{}');
      File(p.join(tempDir.path, 'bun.lock')).createSync();

      final pm = inferPackageManager(
        targetDir: tempDir,
        selectedPackageDir: tempDir,
        packageFile: pkg,
        isBun: true,
      );
      expect(pm, equals('bun'));
    });

    test('inferPackageManager detects pnpm when pnpm-lock.yaml is present', () {
      final pkg = File(p.join(tempDir.path, 'package.json'))..writeAsStringSync('{}');
      File(p.join(tempDir.path, 'pnpm-lock.yaml')).createSync();

      final pm = inferPackageManager(
        targetDir: tempDir,
        selectedPackageDir: tempDir,
        packageFile: pkg,
        isBun: false,
      );
      expect(pm, equals('pnpm'));
    });

    test('inferPackageManager detects yarn when yarn.lock is present', () {
      final pkg = File(p.join(tempDir.path, 'package.json'))..writeAsStringSync('{}');
      File(p.join(tempDir.path, 'yarn.lock')).createSync();

      final pm = inferPackageManager(
        targetDir: tempDir,
        selectedPackageDir: tempDir,
        packageFile: pkg,
        isBun: false,
      );
      expect(pm, equals('yarn'));
    });

    test('inferPackageManager detects npm when package-lock.json is present', () {
      final pkg = File(p.join(tempDir.path, 'package.json'))..writeAsStringSync('{}');
      File(p.join(tempDir.path, 'package-lock.json')).createSync();

      final pm = inferPackageManager(
        targetDir: tempDir,
        selectedPackageDir: tempDir,
        packageFile: pkg,
        isBun: false,
      );
      expect(pm, equals('npm'));
    });

    test('updatePackageJson adds @biomejs/biome and scripts', () async {
      final pkg = File(p.join(tempDir.path, 'package.json'))
        ..writeAsStringSync(json.encode({
          'name': 'test-app',
          'scripts': {'test': 'echo 1'},
          'dependencies': {'react': '^18.0.0'},
        }));

      final logger = Logger();
      await updatePackageJson(
        packageFile: pkg,
        addScripts: true,
        logger: logger,
      );

      final updated = json.decode(pkg.readAsStringSync()) as Map<String, dynamic>;
      expect(updated['devDependencies']['@biomejs/biome'], equals('^1.9.4'));
      expect(updated['scripts']['check'], equals('biome check .'));
      expect(updated['scripts']['lint'], equals('biome lint .'));
      expect(updated['scripts']['format'], equals('biome format --write .'));
      expect(updated['scripts']['test'], equals('echo 1'));
      expect(updated['dependencies']['react'], equals('^18.0.0'));
    });
  });
}
