import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/snippets_dao.dart';

void main() {
  late AppDatabase db;
  late SnippetsDao dao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = SnippetsDao(db);
    // Force Drift to run migrations.
    await dao.getAllCategories();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helper: create a test snippet ────────────────────────

  Future<void> createSnippet({
    String id = 'snip-1',
    String title = 'Test Snippet',
    String code = 'print("hello")',
    String language = 'Python',
    String category = 'utility',
    String description = '',
    String tags = '',
  }) {
    return dao.insertSnippet(SnippetsCompanion.insert(
      id: id,
      title: title,
      code: code,
      language: Value(language),
      category: Value(category),
      description: Value(description),
      tags: Value(tags),
    ),);
  }

  // ── insertSnippet ────────────────────────────────────────

  group('insertSnippet', () {
    test('inserts a snippet into the database', () async {
      await createSnippet();

      final snippet = await dao.getSnippetById('snip-1');
      expect(snippet, isNotNull);
      expect(snippet!.id, 'snip-1');
      expect(snippet.title, 'Test Snippet');
      expect(snippet.code, 'print("hello")');
      expect(snippet.language, 'Python');
      expect(snippet.category, 'utility');
    });

    test('sets default values', () async {
      await createSnippet(id: 'snip-defaults');

      final snippet = await dao.getSnippetById('snip-defaults');
      expect(snippet!.usageCount, 0);
      expect(snippet.description, '');
      expect(snippet.tags, '');
    });

    test('sets createdAt and updatedAt timestamps', () async {
      final before = DateTime.now();
      await createSnippet(id: 'snip-ts');
      final after = DateTime.now();

      final snippet = await dao.getSnippetById('snip-ts');
      expect(
          snippet!.createdAt
              .isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,);
      expect(snippet.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,);
    });
  });

  // ── getSnippetById ───────────────────────────────────────

  group('getSnippetById', () {
    test('returns null for non-existent ID', () async {
      final snippet = await dao.getSnippetById('nonexistent');
      expect(snippet, isNull);
    });

    test('returns the correct snippet', () async {
      await createSnippet(id: 'snip-a', title: 'Snippet A');
      await createSnippet(id: 'snip-b', title: 'Snippet B');

      final result = await dao.getSnippetById('snip-a');
      expect(result, isNotNull);
      expect(result!.title, 'Snippet A');
    });
  });

  // ── searchSnippets ───────────────────────────────────────

  group('searchSnippets', () {
    test('finds snippets by title (case-insensitive)', () async {
      await createSnippet(id: 's1', title: 'Flutter Widget');
      await createSnippet(id: 's2', title: 'Dart Class');

      final results = await dao.searchSnippets('flutter');
      expect(results.length, 1);
      expect(results[0].id, 's1');
    });

    test('finds snippets by language', () async {
      await createSnippet(id: 's-dart', language: 'Dart');
      await createSnippet(id: 's-py', language: 'Python');

      final results = await dao.searchSnippets('dart');
      expect(results.length, 1);
      expect(results[0].id, 's-dart');
    });

    test('finds snippets by category', () async {
      await createSnippet(id: 's-utility', category: 'utility');
      await createSnippet(id: 's-algo', category: 'algorithm');

      final results = await dao.searchSnippets('utility');
      expect(results.length, 1);
      expect(results[0].id, 's-utility');
    });

    test('finds snippets by tags', () async {
      await createSnippet(id: 's-tag1', tags: 'async,flutter');
      await createSnippet(id: 's-tag2', tags: 'sync,io');

      final results = await dao.searchSnippets('async');
      expect(results.length, 1);
      expect(results[0].id, 's-tag1');
    });

    test('returns empty for no match', () async {
      await createSnippet(id: 's-nomatch', title: 'Something');
      final results = await dao.searchSnippets('xyznonexistent');
      expect(results, isEmpty);
    });

    test('returns results ordered by updatedAt descending', () async {
      await createSnippet(id: 's-old', title: 'match old');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      await createSnippet(id: 's-new', title: 'match new');

      final results = await dao.searchSnippets('match');
      expect(results.length, 2);
      expect(results[0].id, 's-new');
      expect(results[1].id, 's-old');
    });
  });

  // ── getSnippetsByCategory ────────────────────────────────

  group('getSnippetsByCategory', () {
    test('returns snippets matching the category', () async {
      await createSnippet(id: 'c1', category: 'testing');
      await createSnippet(id: 'c2', category: 'testing');
      await createSnippet(id: 'c3', category: 'utility');

      final results = await dao.getSnippetsByCategory('testing');
      expect(results.length, 2);
      final ids = results.map((s) => s.id).toSet();
      expect(ids, containsAll(['c1', 'c2']));
    });

    test('returns empty for category with no snippets', () async {
      await createSnippet(category: 'other');
      final results = await dao.getSnippetsByCategory('nonexistent');
      expect(results, isEmpty);
    });
  });

  // ── getSnippetsByLanguage ────────────────────────────────

  group('getSnippetsByLanguage', () {
    test('returns snippets matching the language', () async {
      await createSnippet(id: 'l1', language: 'Dart');
      await createSnippet(id: 'l2', language: 'Dart');
      await createSnippet(id: 'l3', language: 'Go');

      final results = await dao.getSnippetsByLanguage('Dart');
      expect(results.length, 2);
    });

    test('returns empty for language with no snippets', () async {
      await createSnippet(language: 'Dart');
      final results = await dao.getSnippetsByLanguage('Rust');
      expect(results, isEmpty);
    });
  });

  // ── updateSnippet ────────────────────────────────────────

  group('updateSnippet', () {
    test('updates title and code', () async {
      await createSnippet(id: 'snip-upd');

      await dao.updateSnippet(const SnippetsCompanion(
        id: Value('snip-upd'),
        title: Value('Updated Title'),
        code: Value('console.log("hi")'),
      ),);

      final snippet = await dao.getSnippetById('snip-upd');
      expect(snippet!.title, 'Updated Title');
      expect(snippet.code, 'console.log("hi")');
    });

    test('does not insert when updating non-existent ID', () async {
      await dao.updateSnippet(const SnippetsCompanion(
        id: Value('nonexistent'),
        title: Value('Ghost'),
      ),);
      expect(await dao.getSnippetById('nonexistent'), isNull);
    });
  });

  // ── deleteSnippet ────────────────────────────────────────

  group('deleteSnippet', () {
    test('deletes an existing snippet', () async {
      await createSnippet(id: 'snip-del');
      expect(await dao.getSnippetById('snip-del'), isNotNull);

      await dao.deleteSnippet('snip-del');
      expect(await dao.getSnippetById('snip-del'), isNull);
    });

    test('does not throw when deleting non-existent snippet', () async {
      await dao.deleteSnippet('nonexistent');
    });
  });

  // ── incrementUsageCount ──────────────────────────────────

  group('incrementUsageCount', () {
    test('increments usage count from 0 to 1', () async {
      await createSnippet(id: 'snip-usage');
      expect((await dao.getSnippetById('snip-usage'))!.usageCount, 0);

      await dao.incrementUsageCount('snip-usage');
      expect((await dao.getSnippetById('snip-usage'))!.usageCount, 1);
    });

    test('increments usage count multiple times', () async {
      await createSnippet(id: 'snip-multi');
      for (var i = 0; i < 5; i++) {
        await dao.incrementUsageCount('snip-multi');
      }
      expect((await dao.getSnippetById('snip-multi'))!.usageCount, 5);
    });

    test('does not throw for non-existent snippet', () async {
      await dao.incrementUsageCount('nonexistent');
    });
  });

  // ── getAllCategories ─────────────────────────────────────

  group('getAllCategories', () {
    test('returns distinct categories alphabetically', () async {
      await createSnippet(id: 'cat-1', category: 'testing');
      await createSnippet(id: 'cat-2', category: 'algorithm');
      await createSnippet(id: 'cat-3', category: 'testing');
      await createSnippet(id: 'cat-4', category: 'utility');

      final categories = await dao.getAllCategories();
      expect(categories, ['algorithm', 'testing', 'utility']);
    });

    test('excludes empty categories', () async {
      await createSnippet(id: 'cat-empty', category: '');
      await createSnippet(id: 'cat-valid', category: 'valid');

      final categories = await dao.getAllCategories();
      expect(categories, ['valid']);
    });

    test('returns empty list when no snippets exist', () async {
      final categories = await dao.getAllCategories();
      expect(categories, isEmpty);
    });
  });

  // ── getAllLanguages ──────────────────────────────────────

  group('getAllLanguages', () {
    test('returns distinct languages alphabetically', () async {
      await createSnippet(id: 'lang-1', language: 'Python');
      await createSnippet(id: 'lang-2', language: 'Dart');
      await createSnippet(id: 'lang-3', language: 'Python');

      final languages = await dao.getAllLanguages();
      expect(languages, ['Dart', 'Python']);
    });

    test('excludes empty languages', () async {
      await createSnippet(id: 'lang-empty', language: '');
      await createSnippet(id: 'lang-go', language: 'Go');

      final languages = await dao.getAllLanguages();
      expect(languages, ['Go']);
    });

    test('returns empty list when no snippets exist', () async {
      final languages = await dao.getAllLanguages();
      expect(languages, isEmpty);
    });
  });

  // ── watchAllSnippets ─────────────────────────────────────

  group('watchAllSnippets', () {
    test('emits initial empty list', () async {
      final stream = dao.watchAllSnippets();
      final first = await stream.first;
      expect(first, isEmpty);
    });
  });
}
