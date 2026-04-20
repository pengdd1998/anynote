import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:anynote/core/storage/image_storage.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // These tests use a real temporary directory on the filesystem.
  // They require a native (non-web) environment.

  late Directory testDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('image_storage_test_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('ImageStorage', () {
    group('saveImage', () {
      test('saves image bytes and returns a valid path', () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final path = await ImageStorage.saveImage(bytes, 'note-abc');

        expect(path, isNotEmpty);
        expect(p.basename(path), startsWith('note-abc_'));
        expect(p.basename(path), endsWith('.png'));

        // Verify the file exists and has the correct content.
        final file = File(path);
        expect(await file.exists(), isTrue);
        final saved = await file.readAsBytes();
        expect(saved, bytes);
      });

      test('generates different filenames for different byte content',
          () async {
        final bytes1 = Uint8List.fromList([1, 2, 3]);
        final bytes2 = Uint8List.fromList([4, 5, 6]);

        final path1 = await ImageStorage.saveImage(bytes1, 'note-same');
        final path2 = await ImageStorage.saveImage(bytes2, 'note-same');

        expect(path1, isNot(equals(path2)));
      });

      test('generates same filename for identical byte content', () async {
        final bytes = Uint8List.fromList([10, 20, 30]);

        final path1 = await ImageStorage.saveImage(bytes, 'note-dup');
        final path2 = await ImageStorage.saveImage(bytes, 'note-dup');

        // Same content should produce the same MD5 hash and thus the same path.
        expect(path1, equals(path2));
      });

      test('path contains note_images directory segment', () async {
        final bytes = Uint8List.fromList([42]);
        final path = await ImageStorage.saveImage(bytes, 'note-path');

        // The path should contain the 'note_images' directory.
        expect(path, contains('note_images'));
      });

      test('MD5 hash in filename uses first 12 hex chars', () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final path = await ImageStorage.saveImage(bytes, 'note-hash');

        final filename = p.basename(path);
        // Format is {noteId}_{12charhash}.png
        // Strip prefix and suffix to extract the hash part.
        final hashPart =
            filename.replaceFirst('note-hash_', '').replaceAll('.png', '');

        expect(hashPart.length, 12);
        // Should be hex characters.
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(hashPart), isTrue);
      });

      test('saves large image data correctly', () async {
        final bytes = Uint8List.fromList(
          List.generate(100000, (i) => i % 256),
        );
        final path = await ImageStorage.saveImage(bytes, 'note-large');

        final saved = await File(path).readAsBytes();
        expect(saved.length, 100000);
        expect(saved, bytes);
      });

      test('handles empty byte array', () async {
        final bytes = Uint8List(0);
        final path = await ImageStorage.saveImage(bytes, 'note-empty');

        expect(path, isNotEmpty);
        final saved = await File(path).readAsBytes();
        expect(saved, isEmpty);
      });

      test('overwrites existing file with same content', () async {
        final bytes = Uint8List.fromList([7, 8, 9]);

        final path1 = await ImageStorage.saveImage(bytes, 'note-ow');
        // Write different content to the same path.
        await File(path1).writeAsBytes([99, 99, 99]);

        // Save the original bytes again -- should overwrite.
        final path2 = await ImageStorage.saveImage(bytes, 'note-ow');
        expect(path2, equals(path1));

        final saved = await File(path2).readAsBytes();
        expect(saved, bytes);
      });
    });

    group('loadImage', () {
      test('returns image bytes for existing file', () async {
        final bytes = Uint8List.fromList([10, 20, 30, 40]);
        final path = await ImageStorage.saveImage(bytes, 'note-load');

        final loaded = await ImageStorage.loadImage(path);

        expect(loaded, isNotNull);
        expect(loaded, bytes);
      });

      test('returns null for non-existent file', () async {
        final path = p.join(testDir.path, 'nonexistent.png');

        final loaded = await ImageStorage.loadImage(path);

        expect(loaded, isNull);
      });

      test('returns correct bytes after multiple saves', () async {
        final bytes1 = Uint8List.fromList([1, 2, 3]);
        final bytes2 = Uint8List.fromList([4, 5, 6]);

        final path1 = await ImageStorage.saveImage(bytes1, 'note-multi');
        final path2 = await ImageStorage.saveImage(bytes2, 'note-multi');

        final loaded1 = await ImageStorage.loadImage(path1);
        final loaded2 = await ImageStorage.loadImage(path2);

        expect(loaded1, bytes1);
        expect(loaded2, bytes2);
      });
    });

    group('deleteImagesForNote', () {
      test('deletes all images for a given note ID', () async {
        // Create two images for the same note.
        final bytes1 = Uint8List.fromList([1, 2, 3]);
        final bytes2 = Uint8List.fromList([4, 5, 6]);
        await ImageStorage.saveImage(bytes1, 'note-del');
        await ImageStorage.saveImage(bytes2, 'note-del');

        await ImageStorage.deleteImagesForNote('note-del');

        // Verify files are deleted by checking the images directory.
        final imagesDir = await _getImagesDirectory();
        if (await imagesDir.exists()) {
          await for (final entity in imagesDir.list()) {
            if (entity is File) {
              expect(
                p.basename(entity.path).startsWith('note-del'),
                isFalse,
                reason: 'Found undeleted file: ${entity.path}',
              );
            }
          }
        }
      });

      test('does not delete images for other notes', () async {
        final keepBytes = Uint8List.fromList([100, 200]);
        final deleteBytes = Uint8List.fromList([1, 2]);

        final keepPath =
            await ImageStorage.saveImage(keepBytes, 'note-keep');
        await ImageStorage.saveImage(deleteBytes, 'note-rm');

        await ImageStorage.deleteImagesForNote('note-rm');

        // The kept image should still exist.
        final loaded = await ImageStorage.loadImage(keepPath);
        expect(loaded, isNotNull);
        expect(loaded, keepBytes);
      });

      test('is a no-op when no images exist for the note', () async {
        // Should not throw.
        await ImageStorage.deleteImagesForNote('nonexistent-note');
      });

      test('is a no-op when the images directory does not exist', () async {
        // Delete any existing directory first.
        final dir = await _getImagesDirectory();
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }

        // Should not throw.
        await ImageStorage.deleteImagesForNote('any-note');
      });
    });

    group('round-trip: save, load, delete', () {
      test('full lifecycle works correctly', () async {
        final bytes =
            Uint8List.fromList(List.generate(500, (i) => i % 256));

        // Save.
        final path =
            await ImageStorage.saveImage(bytes, 'note-lifecycle');
        expect(path, isNotEmpty);

        // Load and verify.
        final loaded = await ImageStorage.loadImage(path);
        expect(loaded, bytes);

        // Delete.
        await ImageStorage.deleteImagesForNote('note-lifecycle');

        // Verify deleted.
        final afterDelete = await ImageStorage.loadImage(path);
        expect(afterDelete, isNull);
      });

      test('multiple notes with independent lifecycles', () async {
        final bytesA = Uint8List.fromList([1, 1, 1]);
        final bytesB = Uint8List.fromList([2, 2, 2]);

        final pathA = await ImageStorage.saveImage(bytesA, 'note-a');
        final pathB = await ImageStorage.saveImage(bytesB, 'note-b');

        // Delete note A's images.
        await ImageStorage.deleteImagesForNote('note-a');

        // Note B should still be intact.
        final loadedB = await ImageStorage.loadImage(pathB);
        expect(loadedB, bytesB);

        // Note A should be gone.
        final loadedA = await ImageStorage.loadImage(pathA);
        expect(loadedA, isNull);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Get the images directory used by ImageStorage.
/// Mirrors the internal _getImagesDirectory logic.
Future<Directory> _getImagesDirectory() async {
  final appDir = await getApplicationDocumentsDirectory();
  return Directory(p.join(appDir.path, 'note_images'));
}
