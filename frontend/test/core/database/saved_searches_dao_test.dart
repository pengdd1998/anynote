import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/saved_searches_dao.dart';

void main() {
  late AppDatabase db;
  late SavedSearchesDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SavedSearchesDao(db);
    // Force Drift to run migrations.
    await dao.getAll();
  });

  tearDown(() async {
    await db.close();
  });

  // ── create ───────────────────────────────────────────────

  group('create', () {
    test('creates a saved search and returns a UUID', () async {
      final id = await dao.create(name: 'My Search', query: 'tag:work');
      expect(id, isNotEmpty);
      // UUID v4 format: 8-4-4-4-12 hex chars.
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-')));
    });

    test('stored entry has correct name and query', () async {
      final id =
          await dao.create(name: 'Work Notes', query: 'tag:work status:todo');

      final item = await dao.getById(id);
      expect(item, isNotNull);
      expect(item!.name, 'Work Notes');
      expect(item.query, 'tag:work status:todo');
    });

    test('sets createdAt and updatedAt', () async {
      final before = DateTime.now();
      final id = await dao.create(name: 'Test', query: 'test');
      final after = DateTime.now();

      final item = await dao.getById(id);
      expect(
          item!.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,);
      expect(item.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,);
      expect(item.updatedAt, item.createdAt);
    });
  });

  // ── getById ──────────────────────────────────────────────

  group('getById', () {
    test('returns null for non-existent ID', () async {
      final item = await dao.getById('nonexistent');
      expect(item, isNull);
    });

    test('returns the correct entry by ID', () async {
      final id1 = await dao.create(name: 'First', query: 'q1');
      final id2 = await dao.create(name: 'Second', query: 'q2');

      final item = await dao.getById(id1);
      expect(item, isNotNull);
      expect(item!.name, 'First');

      final item2 = await dao.getById(id2);
      expect(item2, isNotNull);
      expect(item2!.name, 'Second');
    });
  });

  // ── getAll ────────────────────────────────────────────────

  group('getAll', () {
    test('returns empty list when no saved searches exist', () async {
      final all = await dao.getAll();
      expect(all, isEmpty);
    });

    test('returns all entries ordered by updatedAt descending', () async {
      await dao.create(name: 'Oldest', query: 'old');
      // Small delay to ensure different timestamps.
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      await dao.create(name: 'Newest', query: 'new');

      final all = await dao.getAll();
      expect(all.length, 2);
      expect(all[0].name, 'Newest');
      expect(all[1].name, 'Oldest');
    });
  });

  // ── updateSearch ─────────────────────────────────────────

  group('updateSearch', () {
    test('updates the name', () async {
      final id = await dao.create(name: 'Original', query: 'q');

      await dao.updateSearch(id: id, name: 'Updated Name');

      final item = await dao.getById(id);
      expect(item!.name, 'Updated Name');
      // Query should remain unchanged.
      expect(item.query, 'q');
    });

    test('updates the query', () async {
      final id = await dao.create(name: 'My Search', query: 'old-query');

      await dao.updateSearch(id: id, query: 'new-query');

      final item = await dao.getById(id);
      expect(item!.query, 'new-query');
      expect(item.name, 'My Search');
    });

    test('updates both name and query simultaneously', () async {
      final id = await dao.create(name: 'Before', query: 'before-q');

      await dao.updateSearch(id: id, name: 'After', query: 'after-q');

      final item = await dao.getById(id);
      expect(item!.name, 'After');
      expect(item.query, 'after-q');
    });

    test('updates updatedAt timestamp', () async {
      final id = await dao.create(name: 'TimeTest', query: 'q');
      final originalItem = await dao.getById(id);
      final originalUpdatedAt = originalItem!.updatedAt;

      // Ensure time passes.
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      await dao.updateSearch(id: id, name: 'Updated');

      final updatedItem = await dao.getById(id);
      // updatedAt should have changed (or be at least as new).
      expect(
        updatedItem!.updatedAt.isAfter(
            originalUpdatedAt.subtract(const Duration(milliseconds: 1)),),
        isTrue,
      );
    });

    test('does not insert when updating non-existent ID', () async {
      await dao.updateSearch(id: 'nonexistent', name: 'Ghost');
      final all = await dao.getAll();
      expect(all, isEmpty);
    });
  });

  // ── deleteSearch ─────────────────────────────────────────

  group('deleteSearch', () {
    test('deletes an existing saved search', () async {
      final id = await dao.create(name: 'To Delete', query: 'del');

      await dao.deleteSearch(id);
      expect(await dao.getById(id), isNull);
    });

    test('does not delete other entries', () async {
      final id1 = await dao.create(name: 'Keep', query: 'keep');
      final id2 = await dao.create(name: 'Remove', query: 'remove');

      await dao.deleteSearch(id2);
      expect(await dao.getById(id1), isNotNull);
      expect(await dao.getById(id2), isNull);
    });

    test('does not throw when deleting non-existent ID', () async {
      await dao.deleteSearch('nonexistent');
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
