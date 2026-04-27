import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/generated_contents_dao.dart';

void main() {
  late AppDatabase db;
  late GeneratedContentsDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = GeneratedContentsDao(db);
    // Force Drift to run migrations.
    await dao.getAll();
  });

  tearDown(() async {
    await db.close();
  });

  // ── create ───────────────────────────────────────────────

  group('create', () {
    test('inserts a generated content entry and returns ID', () async {
      final id = await dao.create(
        id: 'gc-1',
        encryptedBody: 'enc-body-1',
      );
      expect(id, 'gc-1');

      final item = await dao.getById('gc-1');
      expect(item, isNotNull);
      expect(item!.encryptedBody, 'enc-body-1');
      expect(item.plainBody, isNull);
      expect(item.platformStyle, 'generic');
      expect(item.aiModelUsed, '');
      expect(item.isSynced, false);
    });

    test('stores all optional fields', () async {
      await dao.create(
        id: 'gc-full',
        encryptedBody: 'enc-full',
        plainBody: 'plain-full',
        platformStyle: 'xhs',
        aiModelUsed: 'gpt-4',
      );

      final item = await dao.getById('gc-full');
      expect(item, isNotNull);
      expect(item!.plainBody, 'plain-full');
      expect(item.platformStyle, 'xhs');
      expect(item.aiModelUsed, 'gpt-4');
    });

    test('sets createdAt and updatedAt', () async {
      final before = DateTime.now();
      await dao.create(id: 'gc-ts', encryptedBody: 'enc');
      final after = DateTime.now();

      final item = await dao.getById('gc-ts');
      expect(
          item!.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(item.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
      expect(item.updatedAt, item.createdAt);
    });
  });

  // ── getById ──────────────────────────────────────────────

  group('getById', () {
    test('returns null for non-existent ID', () async {
      final item = await dao.getById('nonexistent');
      expect(item, isNull);
    });
  });

  // ── getAll ────────────────────────────────────────────────

  group('getAll', () {
    test('returns empty list when no entries exist', () async {
      final all = await dao.getAll();
      expect(all, isEmpty);
    });

    test('returns all entries ordered by updatedAt descending', () async {
      await dao.create(id: 'gc-old', encryptedBody: 'old');
      // Small delay to ensure different timestamps.
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      await dao.create(id: 'gc-new', encryptedBody: 'new');

      final all = await dao.getAll();
      expect(all.length, 2);
      // Most recently created/updated first.
      expect(all[0].id, 'gc-new');
      expect(all[1].id, 'gc-old');
    });
  });

  // ── updateContent ────────────────────────────────────────

  group('updateContent', () {
    test('updates encryptedBody', () async {
      await dao.create(id: 'gc-upd', encryptedBody: 'old-enc');

      await dao.updateContent(id: 'gc-upd', encryptedBody: 'new-enc');

      final item = await dao.getById('gc-upd');
      expect(item!.encryptedBody, 'new-enc');
    });

    test('updates plainBody', () async {
      await dao.create(id: 'gc-pb', encryptedBody: 'enc');

      await dao.updateContent(id: 'gc-pb', plainBody: 'now plain');

      final item = await dao.getById('gc-pb');
      expect(item!.plainBody, 'now plain');
    });

    test('sets isSynced to false on update', () async {
      await dao.create(id: 'gc-sync', encryptedBody: 'enc');
      await dao.markSynced('gc-sync');
      expect((await dao.getById('gc-sync'))!.isSynced, true);

      await dao.updateContent(id: 'gc-sync', plainBody: 'updated');
      expect((await dao.getById('gc-sync'))!.isSynced, false);
    });

    test('does not update non-existent entry without error', () async {
      // Should not throw.
      await dao.updateContent(id: 'nonexistent', plainBody: 'x');
    });
  });

  // ── deleteContent ────────────────────────────────────────

  group('deleteContent', () {
    test('deletes an existing entry', () async {
      await dao.create(id: 'gc-del', encryptedBody: 'enc');
      expect(await dao.getById('gc-del'), isNotNull);

      await dao.deleteContent('gc-del');
      expect(await dao.getById('gc-del'), isNull);
    });

    test('does not throw when deleting non-existent entry', () async {
      await dao.deleteContent('nonexistent');
    });
  });

  // ── sync status ──────────────────────────────────────────

  group('sync status', () {
    test('getUnsynced returns only unsynced entries', () async {
      await dao.create(id: 'gc-u1', encryptedBody: 'a');
      await dao.create(id: 'gc-u2', encryptedBody: 'b');
      await dao.markSynced('gc-u1');

      final unsynced = await dao.getUnsynced();
      expect(unsynced.length, 1);
      expect(unsynced[0].id, 'gc-u2');
    });

    test('markSynced sets isSynced to true', () async {
      await dao.create(id: 'gc-ms', encryptedBody: 'enc');
      expect((await dao.getById('gc-ms'))!.isSynced, false);

      await dao.markSynced('gc-ms');
      expect((await dao.getById('gc-ms'))!.isSynced, true);
    });

    test('getUnsynced returns empty when all synced', () async {
      await dao.create(id: 'gc-all-synced', encryptedBody: 'enc');
      await dao.markSynced('gc-all-synced');

      final unsynced = await dao.getUnsynced();
      expect(unsynced, isEmpty);
    });
  });

  // ── watchAll ─────────────────────────────────────────────

  group('watchAll', () {
    test('emits initial empty list', () async {
      final stream = dao.watchAll();
      final first = await stream.first;
      expect(first, isEmpty);
    });
  });
}
