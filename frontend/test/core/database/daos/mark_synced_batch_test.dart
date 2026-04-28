import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/collections_dao.dart';
import 'package:anynote/core/database/daos/generated_contents_dao.dart';
import 'package:anynote/core/database/daos/images_dao.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';
import 'package:anynote/core/database/daos/tags_dao.dart';

void main() {
  late AppDatabase db;
  late NotesDao notesDao;
  late TagsDao tagsDao;
  late CollectionsDao collectionsDao;
  late GeneratedContentsDao generatedContentsDao;
  late ImagesDao imagesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notesDao = db.notesDao;
    tagsDao = db.tagsDao;
    collectionsDao = db.collectionsDao;
    generatedContentsDao = db.generatedContentsDao;
    imagesDao = db.imagesDao;
    // Force Drift to run migrations.
    await notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  // ==========================================================================
  // NotesDao.markSyncedBatch
  // ==========================================================================

  group('NotesDao.markSyncedBatch', () {
    test('marks only the specified notes as synced', () async {
      await notesDao.createNote(id: 'note-b1', encryptedContent: 'enc1');
      await notesDao.createNote(id: 'note-b2', encryptedContent: 'enc2');
      await notesDao.createNote(id: 'note-b3', encryptedContent: 'enc3');

      await notesDao.markSyncedBatch(['note-b1', 'note-b2']);

      final n1 = await notesDao.getNoteById('note-b1');
      final n2 = await notesDao.getNoteById('note-b2');
      final n3 = await notesDao.getNoteById('note-b3');
      expect(n1!.isSynced, isTrue);
      expect(n2!.isSynced, isTrue);
      expect(n3!.isSynced, isFalse);
    });

    test('empty list does not throw', () async {
      await notesDao.createNote(id: 'note-empty', encryptedContent: 'enc');
      await notesDao.markSyncedBatch([]);
      final note = await notesDao.getNoteById('note-empty');
      expect(note!.isSynced, isFalse);
    });

    test('non-existent IDs do not throw', () async {
      await notesDao.createNote(id: 'note-ne', encryptedContent: 'enc');
      await notesDao.markSyncedBatch(['nonexistent-note']);
      final note = await notesDao.getNoteById('note-ne');
      expect(note!.isSynced, isFalse);
    });

    test('idempotent -- calling twice is safe', () async {
      await notesDao.createNote(id: 'note-idem', encryptedContent: 'enc');
      await notesDao.markSyncedBatch(['note-idem']);
      await notesDao.markSyncedBatch(['note-idem']);
      final note = await notesDao.getNoteById('note-idem');
      expect(note!.isSynced, isTrue);
    });
  });

  // ==========================================================================
  // TagsDao.markSyncedBatch
  // ==========================================================================

  group('TagsDao.markSyncedBatch', () {
    test('marks only the specified tags as synced', () async {
      await tagsDao.createTag(id: 'tag-b1', encryptedName: 'enc1');
      await tagsDao.createTag(id: 'tag-b2', encryptedName: 'enc2');
      await tagsDao.createTag(id: 'tag-b3', encryptedName: 'enc3');

      await tagsDao.markSyncedBatch(['tag-b1', 'tag-b2']);

      final all = await tagsDao.getAllTags();
      final find = (String id) => all.firstWhere((t) => t.id == id);
      expect(find('tag-b1').isSynced, isTrue);
      expect(find('tag-b2').isSynced, isTrue);
      expect(find('tag-b3').isSynced, isFalse);
    });

    test('empty list does not throw', () async {
      await tagsDao.createTag(id: 'tag-empty', encryptedName: 'enc');
      await tagsDao.markSyncedBatch([]);
      final all = await tagsDao.getAllTags();
      expect(all[0].isSynced, isFalse);
    });

    test('non-existent IDs do not throw', () async {
      await tagsDao.createTag(id: 'tag-ne', encryptedName: 'enc');
      await tagsDao.markSyncedBatch(['nonexistent-tag']);
      final all = await tagsDao.getAllTags();
      expect(all[0].isSynced, isFalse);
    });

    test('idempotent -- calling twice is safe', () async {
      await tagsDao.createTag(id: 'tag-idem', encryptedName: 'enc');
      await tagsDao.markSyncedBatch(['tag-idem']);
      await tagsDao.markSyncedBatch(['tag-idem']);
      final all = await tagsDao.getAllTags();
      expect(all[0].isSynced, isTrue);
    });
  });

  // ==========================================================================
  // CollectionsDao.markSyncedBatch
  // ==========================================================================

  group('CollectionsDao.markSyncedBatch', () {
    test('marks only the specified collections as synced', () async {
      await collectionsDao.createCollection(
          id: 'col-b1', encryptedTitle: 'enc1');
      await collectionsDao.createCollection(
          id: 'col-b2', encryptedTitle: 'enc2');
      await collectionsDao.createCollection(
          id: 'col-b3', encryptedTitle: 'enc3');

      await collectionsDao.markSyncedBatch(['col-b1', 'col-b2']);

      final all = await collectionsDao.getAllCollections();
      final find = (String id) => all.firstWhere((c) => c.id == id);
      expect(find('col-b1').isSynced, isTrue);
      expect(find('col-b2').isSynced, isTrue);
      expect(find('col-b3').isSynced, isFalse);
    });

    test('empty list does not throw', () async {
      await collectionsDao.createCollection(
          id: 'col-empty', encryptedTitle: 'enc');
      await collectionsDao.markSyncedBatch([]);
      final all = await collectionsDao.getAllCollections();
      expect(all[0].isSynced, isFalse);
    });

    test('non-existent IDs do not throw', () async {
      await collectionsDao.createCollection(
          id: 'col-ne', encryptedTitle: 'enc');
      await collectionsDao.markSyncedBatch(['nonexistent-col']);
      final all = await collectionsDao.getAllCollections();
      expect(all[0].isSynced, isFalse);
    });

    test('idempotent -- calling twice is safe', () async {
      await collectionsDao.createCollection(
          id: 'col-idem', encryptedTitle: 'enc');
      await collectionsDao.markSyncedBatch(['col-idem']);
      await collectionsDao.markSyncedBatch(['col-idem']);
      final all = await collectionsDao.getAllCollections();
      expect(all[0].isSynced, isTrue);
    });
  });

  // ==========================================================================
  // GeneratedContentsDao.markSyncedBatch
  // ==========================================================================

  group('GeneratedContentsDao.markSyncedBatch', () {
    test('marks only the specified generated contents as synced', () async {
      await generatedContentsDao.create(id: 'gc-b1', encryptedBody: 'enc1');
      await generatedContentsDao.create(id: 'gc-b2', encryptedBody: 'enc2');
      await generatedContentsDao.create(id: 'gc-b3', encryptedBody: 'enc3');

      await generatedContentsDao.markSyncedBatch(['gc-b1', 'gc-b2']);

      final gc1 = await generatedContentsDao.getById('gc-b1');
      final gc2 = await generatedContentsDao.getById('gc-b2');
      final gc3 = await generatedContentsDao.getById('gc-b3');
      expect(gc1!.isSynced, isTrue);
      expect(gc2!.isSynced, isTrue);
      expect(gc3!.isSynced, isFalse);
    });

    test('empty list does not throw', () async {
      await generatedContentsDao.create(id: 'gc-empty', encryptedBody: 'enc');
      await generatedContentsDao.markSyncedBatch([]);
      final gc = await generatedContentsDao.getById('gc-empty');
      expect(gc!.isSynced, isFalse);
    });

    test('non-existent IDs do not throw', () async {
      await generatedContentsDao.create(id: 'gc-ne', encryptedBody: 'enc');
      await generatedContentsDao.markSyncedBatch(['nonexistent-gc']);
      final gc = await generatedContentsDao.getById('gc-ne');
      expect(gc!.isSynced, isFalse);
    });

    test('idempotent -- calling twice is safe', () async {
      await generatedContentsDao.create(id: 'gc-idem', encryptedBody: 'enc');
      await generatedContentsDao.markSyncedBatch(['gc-idem']);
      await generatedContentsDao.markSyncedBatch(['gc-idem']);
      final gc = await generatedContentsDao.getById('gc-idem');
      expect(gc!.isSynced, isTrue);
    });
  });

  // ==========================================================================
  // ImagesDao.markSyncedBatch
  // ==========================================================================

  group('ImagesDao.markSyncedBatch', () {
    // Helper to insert a test image.
    Future<void> insertImage({
      required String id,
      String noteId = 'note-img',
      String path = '/tmp/test.png',
      String hash = 'abc123',
      int fileSize = 1024,
      int width = 800,
      int height = 600,
    }) async {
      await imagesDao.insertImage(
        NoteImagesCompanion.insert(
          id: id,
          noteId: Value(noteId),
          path: path,
          hash: hash,
          fileSize: Value(fileSize),
          width: Value(width),
          height: Value(height),
        ),
      );
    }

    test('marks only the specified images as synced', () async {
      await insertImage(id: 'img-b1');
      await insertImage(id: 'img-b2');
      await insertImage(id: 'img-b3');

      await imagesDao.markSyncedBatch(['img-b1', 'img-b2']);

      final i1 = await imagesDao.getImageById('img-b1');
      final i2 = await imagesDao.getImageById('img-b2');
      final i3 = await imagesDao.getImageById('img-b3');
      expect(i1!.isSynced, isTrue);
      expect(i2!.isSynced, isTrue);
      expect(i3!.isSynced, isFalse);
    });

    test('empty list does not throw', () async {
      await insertImage(id: 'img-empty');
      await imagesDao.markSyncedBatch([]);
      final img = await imagesDao.getImageById('img-empty');
      expect(img!.isSynced, isFalse);
    });

    test('non-existent IDs do not throw', () async {
      await insertImage(id: 'img-ne');
      await imagesDao.markSyncedBatch(['nonexistent-img']);
      final img = await imagesDao.getImageById('img-ne');
      expect(img!.isSynced, isFalse);
    });

    test('idempotent -- calling twice is safe', () async {
      await insertImage(id: 'img-idem');
      await imagesDao.markSyncedBatch(['img-idem']);
      await imagesDao.markSyncedBatch(['img-idem']);
      final img = await imagesDao.getImageById('img-idem');
      expect(img!.isSynced, isTrue);
    });
  });
}
