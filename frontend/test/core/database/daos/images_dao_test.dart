import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/images_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ImagesDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').getSingle();
    dao = db.imagesDao;
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper to insert a test image.
  // ---------------------------------------------------------------------------
  Future<void> _insertImage({
    required String id,
    String noteId = 'note-1',
    String path = '/tmp/test.png',
    String hash = 'abc123',
    int fileSize = 1024,
    int width = 800,
    int height = 600,
    bool isSynced = false,
  }) async {
    await dao.insertImage(
      NoteImagesCompanion.insert(
        id: id,
        noteId: Value(noteId),
        path: path,
        hash: hash,
        fileSize: Value(fileSize),
        width: Value(width),
        height: Value(height),
        isSynced: Value(isSynced),
      ),
    );
  }

  group('insertImage', () {
    test('inserts a new image record', () async {
      await _insertImage(id: 'img-1');

      final image = await dao.getImageById('img-1');
      expect(image, isNotNull);
      expect(image!.id, 'img-1');
      expect(image.noteId, 'note-1');
      expect(image.path, '/tmp/test.png');
      expect(image.hash, 'abc123');
      expect(image.fileSize, 1024);
      expect(image.width, 800);
      expect(image.height, 600);
      expect(image.isSynced, isFalse);
    });

    test('inserts image with empty noteId default', () async {
      await _insertImage(id: 'img-empty-note', noteId: '');

      final image = await dao.getImageById('img-empty-note');
      expect(image, isNotNull);
      expect(image!.noteId, '');
    });

    test('inserts multiple images for same note', () async {
      await _insertImage(id: 'img-a', noteId: 'note-multi');
      await _insertImage(id: 'img-b', noteId: 'note-multi');
      await _insertImage(id: 'img-c', noteId: 'note-multi');

      final images = await dao.getImagesForNote('note-multi');
      expect(images.length, 3);
    });

    test('sets createdAt timestamp automatically', () async {
      await _insertImage(id: 'img-ts');

      final image = await dao.getImageById('img-ts');
      expect(image, isNotNull);
      expect(image!.createdAt, isNotNull);
    });
  });

  group('getImagesForNote', () {
    test('returns empty list for note with no images', () async {
      final images = await dao.getImagesForNote('nonexistent');
      expect(images, isEmpty);
    });

    test('returns only images for the specified note', () async {
      await _insertImage(id: 'img-n1', noteId: 'note-target');
      await _insertImage(id: 'img-n2', noteId: 'note-other');
      await _insertImage(id: 'img-n3', noteId: 'note-target');

      final images = await dao.getImagesForNote('note-target');
      expect(images.length, 2);
      expect(images.every((i) => i.noteId == 'note-target'), isTrue);
    });

    test('returns images ordered by creation time', () async {
      await _insertImage(id: 'img-first', noteId: 'note-ordered');
      // Small delay to ensure different timestamps.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await _insertImage(id: 'img-second', noteId: 'note-ordered');

      final images = await dao.getImagesForNote('note-ordered');
      expect(images.length, 2);
      expect(images[0].id, 'img-first');
      expect(images[1].id, 'img-second');
    });
  });

  group('getImageById', () {
    test('returns null for nonexistent image', () async {
      final image = await dao.getImageById('nonexistent');
      expect(image, isNull);
    });

    test('returns correct image by id', () async {
      await _insertImage(id: 'img-specific', hash: 'unique-hash');

      final image = await dao.getImageById('img-specific');
      expect(image, isNotNull);
      expect(image!.hash, 'unique-hash');
    });

    test('returns different images for different IDs', () async {
      await _insertImage(id: 'img-x', hash: 'hash-x');
      await _insertImage(id: 'img-y', hash: 'hash-y');

      final imageX = await dao.getImageById('img-x');
      final imageY = await dao.getImageById('img-y');

      expect(imageX!.hash, 'hash-x');
      expect(imageY!.hash, 'hash-y');
    });
  });

  group('deleteImage', () {
    test('deletes an existing image', () async {
      await _insertImage(id: 'img-del');

      await dao.deleteImage('img-del');

      final image = await dao.getImageById('img-del');
      expect(image, isNull);
    });

    test('delete on nonexistent ID is a no-op', () async {
      // Should not throw.
      await dao.deleteImage('nonexistent');
    });

    test('does not affect other images', () async {
      await _insertImage(id: 'img-keep');
      await _insertImage(id: 'img-remove');

      await dao.deleteImage('img-remove');

      expect(await dao.getImageById('img-keep'), isNotNull);
      expect(await dao.getImageById('img-remove'), isNull);
    });
  });

  group('deleteImagesForNote', () {
    test('deletes all images for a note', () async {
      await _insertImage(id: 'img-d1', noteId: 'note-del');
      await _insertImage(id: 'img-d2', noteId: 'note-del');
      await _insertImage(id: 'img-d3', noteId: 'note-del');

      final count = await dao.deleteImagesForNote('note-del');
      expect(count, 3);

      final images = await dao.getImagesForNote('note-del');
      expect(images, isEmpty);
    });

    test('does not delete images for other notes', () async {
      await _insertImage(id: 'img-keep', noteId: 'note-keep');
      await _insertImage(id: 'img-del', noteId: 'note-del');

      await dao.deleteImagesForNote('note-del');

      final keepImages = await dao.getImagesForNote('note-keep');
      expect(keepImages.length, 1);
      expect(keepImages[0].id, 'img-keep');
    });

    test('returns 0 for note with no images', () async {
      final count = await dao.deleteImagesForNote('empty-note');
      expect(count, 0);
    });
  });

  group('getUnsyncedImages', () {
    test('returns empty list when all images are synced', () async {
      await _insertImage(id: 'img-synced', isSynced: true);

      final unsynced = await dao.getUnsyncedImages();
      expect(unsynced, isEmpty);
    });

    test('returns images with isSynced = false', () async {
      await _insertImage(id: 'img-unsynced', isSynced: false);
      await _insertImage(id: 'img-synced', isSynced: true);

      final unsynced = await dao.getUnsyncedImages();
      expect(unsynced.length, 1);
      expect(unsynced[0].id, 'img-unsynced');
    });

    test('returns all unsynced images across notes', () async {
      await _insertImage(id: 'img-u1', noteId: 'note-a', isSynced: false);
      await _insertImage(id: 'img-u2', noteId: 'note-b', isSynced: false);
      await _insertImage(id: 'img-u3', noteId: 'note-c', isSynced: false);

      final unsynced = await dao.getUnsyncedImages();
      expect(unsynced.length, 3);
    });

    test('returns empty list when no images exist', () async {
      final unsynced = await dao.getUnsyncedImages();
      expect(unsynced, isEmpty);
    });
  });

  group('markSynced', () {
    test('marks an unsynced image as synced', () async {
      await _insertImage(id: 'img-mark', isSynced: false);

      await dao.markSynced('img-mark');

      final image = await dao.getImageById('img-mark');
      expect(image!.isSynced, isTrue);
    });

    test('image no longer appears in getUnsyncedImages after marking',
        () async {
      await _insertImage(id: 'img-mk', isSynced: false);

      await dao.markSynced('img-mk');

      final unsynced = await dao.getUnsyncedImages();
      expect(unsynced.every((i) => i.id != 'img-mk'), isTrue);
    });

    test('marking already-synced image is a no-op', () async {
      await _insertImage(id: 'img-already', isSynced: true);

      await dao.markSynced('img-already');

      final image = await dao.getImageById('img-already');
      expect(image!.isSynced, isTrue);
    });

    test('marking nonexistent ID is a no-op', () async {
      // Should not throw.
      await dao.markSynced('nonexistent');
    });
  });

  group('full image lifecycle', () {
    test('insert, query, sync, verify, delete', () async {
      // Insert.
      await _insertImage(
        id: 'img-life',
        noteId: 'note-life',
        path: '/tmp/lifecycle.jpg',
        hash: 'lifecycle-hash',
        fileSize: 2048,
        width: 1920,
        height: 1080,
        isSynced: false,
      );

      // Query.
      var images = await dao.getImagesForNote('note-life');
      expect(images.length, 1);
      expect(images[0].isSynced, isFalse);

      // Verify unsynced list.
      var unsynced = await dao.getUnsyncedImages();
      expect(unsynced.any((i) => i.id == 'img-life'), isTrue);

      // Mark synced.
      await dao.markSynced('img-life');

      // Verify synced.
      unsynced = await dao.getUnsyncedImages();
      expect(unsynced.every((i) => i.id != 'img-life'), isTrue);

      final synced = await dao.getImageById('img-life');
      expect(synced!.isSynced, isTrue);

      // Delete.
      await dao.deleteImagesForNote('note-life');
      images = await dao.getImagesForNote('note-life');
      expect(images, isEmpty);
    });
  });
}
