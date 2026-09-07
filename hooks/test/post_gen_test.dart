import 'dart:io';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../post_gen.dart';

void main() {
  group('Biome Brick post_gen hook', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('biome_post_gen_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('relocateBiomeJson moves biome.json to destination directory', () {
      final rootBiomeFile = File(p.join(tempDir.path, 'biome.json'))
        ..writeAsStringSync('{"root": true}');
      final subDir = Directory(p.join(tempDir.path, 'packages', 'app'));

      relocateBiomeJson(
        targetDir: tempDir,
        destinationDir: subDir,
        logger: Logger(level: Level.quiet),
      );

      expect(rootBiomeFile.existsSync(), isFalse);
      final destBiomeFile = File(p.join(subDir.path, 'biome.json'));
      expect(destBiomeFile.existsSync(), isTrue);
      expect(destBiomeFile.readAsStringSync(), equals('{"root": true}'));
    });

    test('relocateBiomeJson does nothing when source and destination are the same', () {
      final rootBiomeFile = File(p.join(tempDir.path, 'biome.json'))
        ..writeAsStringSync('{"root": true}');

      relocateBiomeJson(
        targetDir: tempDir,
        destinationDir: tempDir,
        logger: Logger(level: Level.quiet),
      );

      expect(rootBiomeFile.existsSync(), isTrue);
    });

    test('relocateBiomeJson handles missing source file gracefully', () {
      final subDir = Directory(p.join(tempDir.path, 'packages', 'app'));

      expect(
        () => relocateBiomeJson(
          targetDir: tempDir,
          destinationDir: subDir,
          logger: Logger(level: Level.quiet),
        ),
        returnsNormally,
      );
    });
  });
}

