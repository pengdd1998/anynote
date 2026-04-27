import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/sync_meta_dao.dart';

void main() {
  late AppDatabase db;
  late SyncMetaDao syncMetaDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncMetaDao = SyncMetaDao(db);
    // Force Drift to run migrations.
    await syncMetaDao.getAll();
  });

  tearDown(() async {
    await db.close();
  });

  // ── getLastSyncedVersion ─────────────────────────────────

  group('getLastSyncedVersion', () {
    test('returns 0 when no metadata exists for item type', () async {
      final version = await syncMetaDao.getLastSyncedVersion('notes');
      expect(version, 0);
    });

    test('returns stored version after update', () async {
      await syncMetaDao.updateSyncMeta('notes', 42);
      final version = await syncMetaDao.getLastSyncedVersion('notes');
      expect(version, 42);
    });
  });

  // ── updateSyncMeta ───────────────────────────────────────

  group('updateSyncMeta', () {
    test('inserts new metadata entry', () async {
      await syncMetaDao.updateSyncMeta('tags', 10);

      final all = await syncMetaDao.getAll();
      expect(all.length, 1);
      expect(all[0].itemType, 'tags');
      expect(all[0].lastSyncedVersion, 10);
      expect(all[0].lastSyncedAt, isNotNull);
    });

    test('upserts existing metadata entry (replace mode)', () async {
      await syncMetaDao.updateSyncMeta('notes', 5);
      await syncMetaDao.updateSyncMeta('notes', 15);

      final all = await syncMetaDao.getAll();
      // Should be one entry, not two.
      expect(all.length, 1);
      expect(all[0].itemType, 'notes');
      expect(all[0].lastSyncedVersion, 15);
    });

    test('stores different item types separately', () async {
      await syncMetaDao.updateSyncMeta('notes', 10);
      await syncMetaDao.updateSyncMeta('tags', 20);
      await syncMetaDao.updateSyncMeta('collections', 30);

      final all = await syncMetaDao.getAll();
      expect(all.length, 3);

      final notesVersion = await syncMetaDao.getLastSyncedVersion('notes');
      final tagsVersion = await syncMetaDao.getLastSyncedVersion('tags');
      final collectionsVersion =
          await syncMetaDao.getLastSyncedVersion('collections');
      expect(notesVersion, 10);
      expect(tagsVersion, 20);
      expect(collectionsVersion, 30);
    });

    test('sets lastSyncedAt to a recent timestamp', () async {
      final before = DateTime.now();
      await syncMetaDao.updateSyncMeta('notes', 1);
      final after = DateTime.now();

      final all = await syncMetaDao.getAll();
      final syncedAt = all[0].lastSyncedAt;
      expect(syncedAt, isNotNull);
      expect(syncedAt!.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(syncedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  // ── getAll ────────────────────────────────────────────────

  group('getAll', () {
    test('returns empty list when no metadata exists', () async {
      final all = await syncMetaDao.getAll();
      expect(all, isEmpty);
    });

    test('returns all metadata entries', () async {
      await syncMetaDao.updateSyncMeta('notes', 1);
      await syncMetaDao.updateSyncMeta('tags', 2);
      await syncMetaDao.updateSyncMeta('collections', 3);
      await syncMetaDao.updateSyncMeta('generated_contents', 4);

      final all = await syncMetaDao.getAll();
      expect(all.length, 4);
    });
  });
}
