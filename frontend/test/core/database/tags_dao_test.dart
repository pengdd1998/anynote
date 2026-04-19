import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';
import 'package:anynote/core/database/daos/tags_dao.dart';

void main() {
  late AppDatabase db;
  late TagsDao tagsDao;
  late NotesDao notesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tagsDao = TagsDao(db);
    notesDao = NotesDao(db);
    // Force Drift to run migrations.
    await tagsDao.getAllTags();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helper ──────────────────────────────────────────────

  Future<String> createTag({
    String id = 'tag-1',
    String encryptedName = 'ZW5jLXRhZw==',
    String? plainName,
  }) {
    return tagsDao.createTag(
      id: id,
      encryptedName: encryptedName,
      plainName: plainName,
    );
  }

  // ── Create / Read ───────────────────────────────────────

  group('create and read', () {
    test('createTag inserts a tag and returns its ID', () async {
      final id = await createTag(plainName: 'work');
      expect(id, 'tag-1');

      final allTags = await tagsDao.getAllTags();
      expect(allTags.length, 1);
      expect(allTags[0].id, 'tag-1');
      expect(allTags[0].encryptedName, 'ZW5jLXRhZw==');
      expect(allTags[0].plainName, 'work');
    });

    test('createTag without plainName stores null', () async {
      await createTag();

      final allTags = await tagsDao.getAllTags();
      expect(allTags.length, 1);
      expect(allTags[0].plainName, isNull);
    });

    test('createTag sets default version to 0 and isSynced to false',
        () async {
      await createTag();

      final allTags = await tagsDao.getAllTags();
      expect(allTags[0].version, 0);
      expect(allTags[0].isSynced, false);
    });

    test('getAllTags returns tags ordered by plainName ascending', () async {
      await createTag(id: 'tag-c', plainName: 'zebra');
      await createTag(id: 'tag-a', plainName: 'alpha');
      await createTag(id: 'tag-b', plainName: 'beta');

      final allTags = await tagsDao.getAllTags();
      expect(allTags.length, 3);
      expect(allTags[0].plainName, 'alpha');
      expect(allTags[1].plainName, 'beta');
      expect(allTags[2].plainName, 'zebra');
    });

    test('getAllTags with null plainName -- nulls sort first', () async {
      await createTag(id: 'tag-null');
      await createTag(id: 'tag-named', plainName: 'named');

      final allTags = await tagsDao.getAllTags();
      // SQLite sorts nulls first in ascending order
      expect(allTags[0].plainName, isNull);
      expect(allTags[1].plainName, 'named');
    });
  });

  // ── Update ──────────────────────────────────────────────

  group('update', () {
    test('updateTag changes encryptedName and plainName', () async {
      await createTag(id: 'tag-upd', plainName: 'old name');

      await tagsDao.updateTag(
        id: 'tag-upd',
        encryptedName: 'new-enc-name',
        plainName: 'new name',
      );

      final allTags = await tagsDao.getAllTags();
      expect(allTags.length, 1);
      expect(allTags[0].encryptedName, 'new-enc-name');
      expect(allTags[0].plainName, 'new name');
    });

    test('updateTag sets isSynced to false', () async {
      await createTag(id: 'tag-sync');
      await tagsDao.markSynced('tag-sync');

      // Verify synced
      var unsynced = await tagsDao.getUnsyncedTags();
      expect(unsynced, isEmpty);

      await tagsDao.updateTag(id: 'tag-sync', plainName: 'updated');

      unsynced = await tagsDao.getUnsyncedTags();
      expect(unsynced.length, 1);
      expect(unsynced[0].id, 'tag-sync');
    });

    test('updateTag without encryptedName keeps existing value', () async {
      await createTag(id: 'tag-keep', encryptedName: 'original-enc');

      await tagsDao.updateTag(id: 'tag-keep', plainName: 'updated name');

      final allTags = await tagsDao.getAllTags();
      expect(allTags[0].encryptedName, 'original-enc');
      expect(allTags[0].plainName, 'updated name');
    });

    test('updateTag on non-existent tag does not insert', () async {
      await tagsDao.updateTag(id: 'nonexistent', plainName: 'ghost');

      final allTags = await tagsDao.getAllTags();
      expect(allTags, isEmpty);
    });
  });

  // ── Delete ──────────────────────────────────────────────

  group('delete', () {
    test('deleteTag removes the tag', () async {
      await createTag(id: 'tag-del', plainName: 'to delete');
      expect((await tagsDao.getAllTags()).length, 1);

      await tagsDao.deleteTag('tag-del');
      expect((await tagsDao.getAllTags()).length, 0);
    });

    test('deleteTag also removes note-tag associations', () async {
      // Create a note and a tag, then link them
      await notesDao.createNote(
        id: 'note-del-tag',
        encryptedContent: 'enc',
        plainContent: 'content',
      );
      await createTag(id: 'tag-del-assoc');
      await notesDao.addTagToNote('note-del-tag', 'tag-del-assoc');

      // Verify the link exists
      var taggedNotes = await tagsDao.getTagsForNote('note-del-tag');
      expect(taggedNotes.length, 1);

      // Delete the tag
      await tagsDao.deleteTag('tag-del-assoc');

      // Association should be gone
      taggedNotes = await tagsDao.getTagsForNote('note-del-tag');
      expect(taggedNotes, isEmpty);
    });

    test('deleteTag on non-existent tag does not throw', () async {
      // Should complete without error
      await tagsDao.deleteTag('nonexistent');
    });
  });

  // ── Tags for note ───────────────────────────────────────

  group('tags for note', () {
    test('getTagsForNote returns tags associated with a note', () async {
      await notesDao.createNote(
        id: 'note-tn',
        encryptedContent: 'enc',
      );
      await createTag(id: 'tag-tn-1', plainName: 'work');
      await createTag(id: 'tag-tn-2', plainName: 'personal');
      await notesDao.addTagToNote('note-tn', 'tag-tn-1');
      await notesDao.addTagToNote('note-tn', 'tag-tn-2');

      final tags = await tagsDao.getTagsForNote('note-tn');
      expect(tags.length, 2);
      final names = tags.map((t) => t.plainName).toSet();
      expect(names, containsAll(['work', 'personal']));
    });

    test('getTagsForNote returns empty for note with no tags', () async {
      await notesDao.createNote(
        id: 'note-no-tags',
        encryptedContent: 'enc',
      );

      final tags = await tagsDao.getTagsForNote('note-no-tags');
      expect(tags, isEmpty);
    });

    test('getTagsForNote returns empty for non-existent note', () async {
      final tags = await tagsDao.getTagsForNote('nonexistent');
      expect(tags, isEmpty);
    });
  });

  // ── Sync status ─────────────────────────────────────────

  group('sync status', () {
    test('getUnsyncedTags returns only unsynced tags', () async {
      await createTag(id: 'tag-synced', plainName: 'synced');
      await createTag(id: 'tag-unsynced', plainName: 'unsynced');

      await tagsDao.markSynced('tag-synced');

      final unsynced = await tagsDao.getUnsyncedTags();
      expect(unsynced.length, 1);
      expect(unsynced[0].id, 'tag-unsynced');
    });

    test('markSynced sets isSynced to true', () async {
      await createTag(id: 'tag-ms');
      var allTags = await tagsDao.getAllTags();
      expect(allTags[0].isSynced, false);

      await tagsDao.markSynced('tag-ms');

      allTags = await tagsDao.getAllTags();
      expect(allTags[0].isSynced, true);
    });

    test('getUnsyncedTags returns empty when all synced', () async {
      await createTag(id: 'tag-s1');
      await tagsDao.markSynced('tag-s1');

      final unsynced = await tagsDao.getUnsyncedTags();
      expect(unsynced, isEmpty);
    });
  });

  // ── Watch ───────────────────────────────────────────────

  group('watchAllTags', () {
    test('emits initial empty list', () async {
      final stream = tagsDao.watchAllTags();
      final first = await stream.first;
      expect(first, isEmpty);
    });
  });
}
