import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/collections_dao.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';

void main() {
  late AppDatabase db;
  late CollectionsDao collectionsDao;
  late NotesDao notesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    collectionsDao = CollectionsDao(db);
    notesDao = NotesDao(db);
    // Force Drift to run migrations.
    await collectionsDao.getAllCollections();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helper ──────────────────────────────────────────────

  Future<String> createCollection({
    String id = 'col-1',
    String encryptedTitle = 'ZW5jLXRpdGxl',
    String? plainTitle,
  }) {
    return collectionsDao.createCollection(
      id: id,
      encryptedTitle: encryptedTitle,
      plainTitle: plainTitle,
    );
  }

  Future<void> createNote({String id = 'note-1'}) {
    return notesDao.createNote(
      id: id,
      encryptedContent: 'enc-content',
      plainContent: 'plain content',
    );
  }

  // ── Create / Read ───────────────────────────────────────

  group('create and read', () {
    test('createCollection inserts a collection and returns its ID', () async {
      final id = await createCollection(plainTitle: 'Work Notes');
      expect(id, 'col-1');

      final all = await collectionsDao.getAllCollections();
      expect(all.length, 1);
      expect(all[0].id, 'col-1');
      expect(all[0].plainTitle, 'Work Notes');
    });

    test('createCollection without plainTitle stores null', () async {
      await createCollection();

      final all = await collectionsDao.getAllCollections();
      expect(all[0].plainTitle, isNull);
    });

    test('createCollection sets default version to 0 and isSynced to false',
        () async {
      await createCollection();

      final all = await collectionsDao.getAllCollections();
      expect(all[0].version, 0);
      expect(all[0].isSynced, false);
    });

    test('getAllCollections returns collections ordered by plainTitle asc',
        () async {
      await createCollection(id: 'col-c', plainTitle: 'zebra notes');
      await createCollection(id: 'col-a', plainTitle: 'alpha notes');
      await createCollection(id: 'col-b', plainTitle: 'beta notes');

      final all = await collectionsDao.getAllCollections();
      expect(all.length, 3);
      expect(all[0].plainTitle, 'alpha notes');
      expect(all[1].plainTitle, 'beta notes');
      expect(all[2].plainTitle, 'zebra notes');
    });
  });

  // ── Update ──────────────────────────────────────────────

  group('update', () {
    test('updateCollection changes encryptedTitle and plainTitle', () async {
      await createCollection(id: 'col-upd', plainTitle: 'old title');

      await collectionsDao.updateCollection(
        id: 'col-upd',
        encryptedTitle: 'new-enc-title',
        plainTitle: 'new title',
      );

      final all = await collectionsDao.getAllCollections();
      expect(all.length, 1);
      expect(all[0].encryptedTitle, 'new-enc-title');
      expect(all[0].plainTitle, 'new title');
    });

    test('updateCollection sets isSynced to false', () async {
      await createCollection(id: 'col-sync');
      await collectionsDao.markSynced('col-sync');
      expect((await collectionsDao.getUnsyncedCollections()), isEmpty);

      await collectionsDao.updateCollection(id: 'col-sync', plainTitle: 'updated');
      expect((await collectionsDao.getUnsyncedCollections()).length, 1);
    });

    test('updateCollection without encryptedTitle keeps existing value',
        () async {
      await createCollection(
        id: 'col-keep',
        encryptedTitle: 'original-enc',
      );

      await collectionsDao.updateCollection(
        id: 'col-keep',
        plainTitle: 'updated title',
      );

      final all = await collectionsDao.getAllCollections();
      expect(all[0].encryptedTitle, 'original-enc');
      expect(all[0].plainTitle, 'updated title');
    });

    test('updateCollection on non-existent collection does not insert',
        () async {
      await collectionsDao.updateCollection(
        id: 'nonexistent',
        plainTitle: 'ghost',
      );

      final all = await collectionsDao.getAllCollections();
      expect(all, isEmpty);
    });
  });

  // ── Delete ──────────────────────────────────────────────

  group('delete', () {
    test('deleteCollection removes the collection', () async {
      await createCollection(id: 'col-del', plainTitle: 'to delete');
      expect((await collectionsDao.getAllCollections()).length, 1);

      await collectionsDao.deleteCollection('col-del');
      expect((await collectionsDao.getAllCollections()).length, 0);
    });

    test('deleteCollection also removes collection-note associations',
        () async {
      await createNote(id: 'note-col-del');
      await createCollection(id: 'col-del-assoc');
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-del-assoc',
        noteId: 'note-col-del',
      );

      // Verify the association exists
      final colNotes =
          await collectionsDao.getCollectionNotes('col-del-assoc');
      expect(colNotes.length, 1);

      // Delete the collection
      await collectionsDao.deleteCollection('col-del-assoc');

      // Collection should be gone
      expect((await collectionsDao.getAllCollections()), isEmpty);

      // Note should still exist (only the association is deleted)
      final note = await notesDao.getNoteById('note-col-del');
      expect(note, isNotNull);
    });

    test('deleteCollection on non-existent ID does not throw', () async {
      await collectionsDao.deleteCollection('nonexistent');
    });
  });

  // ── Collection-Note associations ────────────────────────

  group('collection notes', () {
    test('addNoteToCollection and getCollectionNotes', () async {
      await createNote(id: 'note-cn1');
      await createNote(id: 'note-cn2');
      await createCollection(id: 'col-cn');

      await collectionsDao.addNoteToCollection(
        collectionId: 'col-cn',
        noteId: 'note-cn1',
        sortOrder: 0,
      );
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-cn',
        noteId: 'note-cn2',
        sortOrder: 1,
      );

      final colNotes = await collectionsDao.getCollectionNotes('col-cn');
      expect(colNotes.length, 2);
      expect(colNotes[0].noteId, 'note-cn1');
      expect(colNotes[0].sortOrder, 0);
      expect(colNotes[1].noteId, 'note-cn2');
      expect(colNotes[1].sortOrder, 1);
    });

    test('getCollectionNotes returns empty for empty collection', () async {
      await createCollection(id: 'col-empty');

      final colNotes = await collectionsDao.getCollectionNotes('col-empty');
      expect(colNotes, isEmpty);
    });

    test('removeNoteFromCollection removes the association', () async {
      await createNote(id: 'note-rm');
      await createCollection(id: 'col-rm');
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-rm',
        noteId: 'note-rm',
      );

      expect(
        (await collectionsDao.getCollectionNotes('col-rm')).length,
        1,
      );

      await collectionsDao.removeNoteFromCollection('col-rm', 'note-rm');

      expect(
        (await collectionsDao.getCollectionNotes('col-rm')).length,
        0,
      );
    });

    test('removeNoteFromCollection for non-existent association does nothing',
        () async {
      await createCollection(id: 'col-rm-na');
      // Should not throw
      await collectionsDao.removeNoteFromCollection('col-rm-na', 'nonexistent');
    });

    test('notes ordered by sortOrder', () async {
      await createNote(id: 'note-so-a');
      await createNote(id: 'note-so-b');
      await createNote(id: 'note-so-c');
      await createCollection(id: 'col-so');

      // Add in non-sorted order
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-so',
        noteId: 'note-so-c',
        sortOrder: 2,
      );
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-so',
        noteId: 'note-so-a',
        sortOrder: 0,
      );
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-so',
        noteId: 'note-so-b',
        sortOrder: 1,
      );

      final colNotes = await collectionsDao.getCollectionNotes('col-so');
      expect(colNotes[0].noteId, 'note-so-a');
      expect(colNotes[1].noteId, 'note-so-b');
      expect(colNotes[2].noteId, 'note-so-c');
    });

    test('same note can belong to multiple collections', () async {
      await createNote(id: 'note-multi-col');
      await createCollection(id: 'col-multi-1');
      await createCollection(id: 'col-multi-2');

      await collectionsDao.addNoteToCollection(
        collectionId: 'col-multi-1',
        noteId: 'note-multi-col',
      );
      await collectionsDao.addNoteToCollection(
        collectionId: 'col-multi-2',
        noteId: 'note-multi-col',
      );

      expect(
        (await collectionsDao.getCollectionNotes('col-multi-1')).length,
        1,
      );
      expect(
        (await collectionsDao.getCollectionNotes('col-multi-2')).length,
        1,
      );
    });
  });

  // ── Sync status ─────────────────────────────────────────

  group('sync status', () {
    test('getUnsyncedCollections returns only unsynced', () async {
      await createCollection(id: 'col-synced', plainTitle: 'synced');
      await createCollection(id: 'col-unsynced', plainTitle: 'unsynced');

      await collectionsDao.markSynced('col-synced');

      final unsynced = await collectionsDao.getUnsyncedCollections();
      expect(unsynced.length, 1);
      expect(unsynced[0].id, 'col-unsynced');
    });

    test('markSynced sets isSynced to true', () async {
      await createCollection(id: 'col-ms');
      var all = await collectionsDao.getAllCollections();
      expect(all[0].isSynced, false);

      await collectionsDao.markSynced('col-ms');

      all = await collectionsDao.getAllCollections();
      expect(all[0].isSynced, true);
    });

    test('getUnsyncedCollections returns empty when all synced', () async {
      await createCollection(id: 'col-s1');
      await collectionsDao.markSynced('col-s1');

      final unsynced = await collectionsDao.getUnsyncedCollections();
      expect(unsynced, isEmpty);
    });
  });

  // ── Watch ───────────────────────────────────────────────

  group('watchAllCollections', () {
    test('emits initial empty list', () async {
      final stream = collectionsDao.watchAllCollections();
      final first = await stream.first;
      expect(first, isEmpty);
    });
  });
}
