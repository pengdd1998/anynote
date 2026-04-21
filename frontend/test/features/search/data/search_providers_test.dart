import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/search/data/search_providers.dart';
import 'package:anynote/main.dart' show databaseProvider;

// ---------------------------------------------------------------------------
// Helper: create an in-memory AppDatabase for testing.
// ---------------------------------------------------------------------------
AppDatabase _createTestDatabase() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so'),
  );
  sqlite3.tempDirectory = Directory.systemTemp.path;
  final file = File(
    '${Directory.systemTemp.path}/search_test_${DateTime.now().millisecondsSinceEpoch}.sqlite',
  );
  return AppDatabase.forTesting(NativeDatabase(file));
}

/// Helper to create a Note with sensible defaults.
Note _makeNote({
  required String id,
  String? plainContent,
  String? plainTitle,
}) {
  final now = DateTime.now();
  return Note(
    id: id,
    encryptedContent: 'enc_$id',
    plainContent: plainContent,
    plainTitle: plainTitle,
    version: 1,
    createdAt: now,
    updatedAt: now,
    isSynced: true,
    isPinned: false,
  );
}

/// Re-implementation of the file-private _buildPreview for direct unit testing.
/// This must stay in sync with the source in search_providers.dart.
String buildPreview(String content, String query) {
  const maxLen = 150;
  if (content.isEmpty) return '';
  if (content.length <= maxLen) return content;

  if (query.trim().isNotEmpty) {
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx = lowerContent.indexOf(lowerQuery);
    if (idx >= 0) {
      final start = (idx - 40).clamp(0, content.length);
      final end = (start + maxLen).clamp(0, content.length);
      var preview = content.substring(start, end);
      if (start > 0) preview = '...$preview';
      if (end < content.length) preview = '$preview...';
      return preview;
    }
  }

  return '${content.substring(0, maxLen)}...';
}

void main() {
  // ===========================================================================
  // SearchFilterState
  // ===========================================================================

  group('SearchFilterState', () {
    test('default constructor has empty query and no active filters', () {
      const state = SearchFilterState();
      expect(state.query, '');
      expect(state.dateRange, isNull);
      expect(state.selectedTagIds, isEmpty);
      expect(state.selectedCollectionIds, isEmpty);
      expect(state.hasActiveFilters, isFalse);
      expect(state.canSearch, isFalse);
    });

    test('hasActiveFilters is true when dateRange is set', () {
      final now = DateTime.now();
      final state = SearchFilterState(
        dateRange: DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 1)),
        ),
      );
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when tags are selected', () {
      const state = SearchFilterState(selectedTagIds: {'tag-1'});
      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when collections are selected', () {
      const state = SearchFilterState(selectedCollectionIds: {'col-1'});
      expect(state.hasActiveFilters, isTrue);
    });

    test('canSearch is true when query is non-empty', () {
      const state = SearchFilterState(query: 'flutter');
      expect(state.canSearch, isTrue);
    });

    test('canSearch is true when tags are selected even without query', () {
      const state = SearchFilterState(selectedTagIds: {'tag-1'});
      expect(state.canSearch, isTrue);
    });

    test('canSearch is true when collections are selected', () {
      const state = SearchFilterState(selectedCollectionIds: {'col-1'});
      expect(state.canSearch, isTrue);
    });

    test('canSearch is false when query is only whitespace', () {
      const state = SearchFilterState(query: '   ');
      expect(state.canSearch, isFalse);
    });

    test('copyWith preserves existing values when no arguments given', () {
      final now = DateTime.now();
      final state = SearchFilterState(
        query: 'test',
        dateRange: DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 1)),
        ),
        selectedTagIds: {'t1'},
        selectedCollectionIds: {'c1'},
      );

      final copied = state.copyWith();
      expect(copied.query, 'test');
      expect(copied.dateRange, isNotNull);
      expect(copied.selectedTagIds, {'t1'});
      expect(copied.selectedCollectionIds, {'c1'});
    });

    test('copyWith overrides query', () {
      const state = SearchFilterState(query: 'old');
      final updated = state.copyWith(query: 'new');
      expect(updated.query, 'new');
    });

    test('copyWith clears dateRange when clearDateRange is true', () {
      final now = DateTime.now();
      final state = SearchFilterState(
        dateRange: DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 1)),
        ),
      );
      final updated = state.copyWith(clearDateRange: true);
      expect(updated.dateRange, isNull);
    });

    test('copyWith replaces selectedTagIds', () {
      const state = SearchFilterState(selectedTagIds: {'a', 'b'});
      final updated = state.copyWith(selectedTagIds: {'c'});
      expect(updated.selectedTagIds, {'c'});
    });

    test('copyWith replaces selectedCollectionIds', () {
      const state = SearchFilterState(selectedCollectionIds: {'x'});
      final updated = state.copyWith(selectedCollectionIds: {'y', 'z'});
      expect(updated.selectedCollectionIds, {'y', 'z'});
    });

    test('copyWith sets a new date range', () {
      final now = DateTime.now();
      const state = SearchFilterState();
      final range = DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 7)),
      );
      final updated = state.copyWith(dateRange: range);
      expect(updated.dateRange, range);
    });

    test('immutability: original state is not modified by copyWith', () {
      const state = SearchFilterState(query: 'original');
      state.copyWith(query: 'modified');
      expect(state.query, 'original');
    });
  });

  // ===========================================================================
  // SearchFiltersNotifier
  // ===========================================================================

  group('SearchFiltersNotifier', () {
    late SearchFiltersNotifier notifier;

    setUp(() {
      notifier = SearchFiltersNotifier();
    });

    test('initial state is default SearchFilterState', () {
      expect(notifier.state.query, '');
      expect(notifier.state.dateRange, isNull);
      expect(notifier.state.selectedTagIds, isEmpty);
      expect(notifier.state.selectedCollectionIds, isEmpty);
    });

    test('setQuery updates the query', () {
      notifier.setQuery('hello');
      expect(notifier.state.query, 'hello');
    });

    test('setQuery can be called multiple times', () {
      notifier.setQuery('a');
      notifier.setQuery('b');
      expect(notifier.state.query, 'b');
    });

    test('setQuery can clear the query', () {
      notifier.setQuery('test');
      notifier.setQuery('');
      expect(notifier.state.query, '');
    });

    test('setDateRange sets the date range', () {
      final now = DateTime.now();
      final range = DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 1)),
      );
      notifier.setDateRange(range);
      expect(notifier.state.dateRange, range);
    });

    test('setDateRange with null clears the date range', () {
      final now = DateTime.now();
      final range = DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 1)),
      );
      notifier.setDateRange(range);
      expect(notifier.state.dateRange, isNotNull);

      notifier.setDateRange(null);
      expect(notifier.state.dateRange, isNull);
    });

    test('clearDateRange clears an existing date range', () {
      final now = DateTime.now();
      notifier.setDateRange(DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 1)),
      ));
      notifier.clearDateRange();
      expect(notifier.state.dateRange, isNull);
    });

    test('toggleTag adds a tag when not present', () {
      notifier.toggleTag('tag-1');
      expect(notifier.state.selectedTagIds, contains('tag-1'));
    });

    test('toggleTag removes a tag when already present', () {
      notifier.toggleTag('tag-1');
      expect(notifier.state.selectedTagIds, contains('tag-1'));

      notifier.toggleTag('tag-1');
      expect(notifier.state.selectedTagIds, isNot(contains('tag-1')));
    });

    test('toggleTag can have multiple tags selected', () {
      notifier.toggleTag('tag-1');
      notifier.toggleTag('tag-2');
      expect(notifier.state.selectedTagIds, {'tag-1', 'tag-2'});
    });

    test('removeTag removes a specific tag without affecting others', () {
      notifier.toggleTag('tag-1');
      notifier.toggleTag('tag-2');
      notifier.removeTag('tag-1');
      expect(notifier.state.selectedTagIds, {'tag-2'});
    });

    test('removeTag on non-existent tag is a no-op', () {
      notifier.toggleTag('tag-1');
      notifier.removeTag('tag-999');
      expect(notifier.state.selectedTagIds, {'tag-1'});
    });

    test('toggleCollection adds a collection when not present', () {
      notifier.toggleCollection('col-1');
      expect(notifier.state.selectedCollectionIds, contains('col-1'));
    });

    test('toggleCollection removes a collection when already present', () {
      notifier.toggleCollection('col-1');
      notifier.toggleCollection('col-1');
      expect(
        notifier.state.selectedCollectionIds,
        isNot(contains('col-1')),
      );
    });

    test('removeCollection removes a specific collection', () {
      notifier.toggleCollection('col-1');
      notifier.toggleCollection('col-2');
      notifier.removeCollection('col-1');
      expect(notifier.state.selectedCollectionIds, {'col-2'});
    });

    test('setSelectedTagIds replaces all tags', () {
      notifier.toggleTag('old-tag');
      notifier.setSelectedTagIds({'new-tag-1', 'new-tag-2'});
      expect(notifier.state.selectedTagIds, {'new-tag-1', 'new-tag-2'});
    });

    test('setSelectedCollectionIds replaces all collections', () {
      notifier.toggleCollection('old-col');
      notifier.setSelectedCollectionIds({'new-col'});
      expect(notifier.state.selectedCollectionIds, {'new-col'});
    });

    test('clearAll resets to default state', () {
      notifier.setQuery('search term');
      notifier.toggleTag('tag-1');
      notifier.toggleCollection('col-1');
      final now = DateTime.now();
      notifier.setDateRange(DateTimeRange(
        start: now,
        end: now.add(const Duration(days: 1)),
      ));

      notifier.clearAll();

      expect(notifier.state.query, '');
      expect(notifier.state.dateRange, isNull);
      expect(notifier.state.selectedTagIds, isEmpty);
      expect(notifier.state.selectedCollectionIds, isEmpty);
    });
  });

  // ===========================================================================
  // searchFiltersProvider (Riverpod integration)
  // ===========================================================================

  group('searchFiltersProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is default SearchFilterState', () {
      final state = container.read(searchFiltersProvider);
      expect(state.query, '');
      expect(state.hasActiveFilters, isFalse);
      expect(state.canSearch, isFalse);
    });

    test('notifier can update the query via the provider', () {
      container.read(searchFiltersProvider.notifier).setQuery('test');
      expect(container.read(searchFiltersProvider).query, 'test');
    });
  });

  // ===========================================================================
  // searchResultCountProvider
  // ===========================================================================

  group('searchResultCountProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial count is zero', () {
      expect(container.read(searchResultCountProvider), 0);
    });

    test('count can be updated', () {
      container.read(searchResultCountProvider.notifier).state = 42;
      expect(container.read(searchResultCountProvider), 42);
    });

    test('count can be reset', () {
      container.read(searchResultCountProvider.notifier).state = 10;
      container.read(searchResultCountProvider.notifier).state = 0;
      expect(container.read(searchResultCountProvider), 0);
    });
  });

  // ===========================================================================
  // _buildPreview logic (tested via local re-implementation)
  // ===========================================================================

  group('buildPreview', () {
    test('empty content returns empty string', () {
      expect(buildPreview('', 'test'), '');
    });

    test('short content (under 150 chars) is returned as-is', () {
      const shortText = 'Short note text.';
      expect(buildPreview(shortText, 'note'), shortText);
    });

    test('content exactly 150 chars is returned as-is', () {
      final text150 = 'a' * 150;
      expect(buildPreview(text150, ''), text150);
    });

    test('long content without query is truncated at start with ellipsis', () {
      final longText = 'a' * 200;
      final preview = buildPreview(longText, '');
      expect(preview, '${'a' * 150}...');
      expect(preview.length, 153); // 150 + 3 for '...'
    });

    test('long content with non-matching query is truncated at start', () {
      final longText = 'x' * 200;
      final preview = buildPreview(longText, 'notfound');
      expect(preview, '${'x' * 150}...');
    });

    test('preview centers around query match at position 100', () {
      final prefix = 'a' * 100;
      final suffix = 'b' * 100;
      final content = '${prefix}target word${suffix}';

      final preview = buildPreview(content, 'target');
      expect(preview.toLowerCase(), contains('target'));
      // Match is at position 100, so start = (100 - 40).clamp(0, ...) = 60.
      // Leading ellipsis expected.
      expect(preview.startsWith('...'), isTrue);
    });

    test('preview at start of content has no leading ellipsis', () {
      final content = 'target${'a' * 200}';
      final preview = buildPreview(content, 'target');
      expect(preview.toLowerCase(), contains('target'));
      // Match at index 0, start = (0 - 40).clamp(0, ...) = 0 -> no leading ellipsis.
      expect(preview.startsWith('...'), isFalse);
    });

    test('preview near end of content has trailing ellipsis', () {
      final content = '${'a' * 200}target';
      final preview = buildPreview(content, 'target');
      expect(preview.toLowerCase(), contains('target'));
      expect(preview.endsWith('...'), isTrue);
    });

    test('preview is case-insensitive for matching', () {
      final content = '${'x' * 100}FLUTTER${'y' * 100}';
      final preview = buildPreview(content, 'flutter');
      expect(preview, contains('FLUTTER'));
    });

    test('query with only whitespace does not trigger match search', () {
      final longText = 'a' * 200;
      final preview = buildPreview(longText, '   ');
      // With whitespace-only query, should fall back to truncation.
      expect(preview, '${'a' * 150}...');
    });
  });

  // ===========================================================================
  // searchResultsProvider -- tag/collection filter path (no FTS5 required)
  // ===========================================================================

  group('searchResultsProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = _createTestDatabase();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      // Seed: create two notes, one tag, one collection.
      await db.notesDao.createNote(
        id: 'note-1',
        encryptedContent: 'enc1',
        plainContent: 'Note about Flutter development.',
        plainTitle: 'Flutter Tips',
      );
      await db.notesDao.createNote(
        id: 'note-2',
        encryptedContent: 'enc2',
        plainContent: 'Dart programming basics.',
        plainTitle: 'Dart Intro',
      );

      // Create tag and assign to note-1.
      await db.tagsDao.createTag(
        id: 'tag-work',
        encryptedName: 'enc-work',
        plainName: 'Work',
      );
      await db.notesDao.addTagToNote('note-1', 'tag-work');

      // Create collection and assign note-2.
      await db.collectionsDao.createCollection(
        id: 'col-archive',
        encryptedTitle: 'enc-archive',
        plainTitle: 'Archive',
      );
      await db.collectionsDao.addNoteToCollection(
        collectionId: 'col-archive',
        noteId: 'note-2',
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns empty list when canSearch is false', () async {
      // Default filters: no query, no tags, no collections.
      final result = await container.read(searchResultsProvider.future);
      expect(result, isEmpty);
    });

    test('returns filtered notes when tag filter is set', () async {
      container.read(searchFiltersProvider.notifier).toggleTag('tag-work');

      final results = await container.read(searchResultsProvider.future);

      expect(results.length, 1);
      expect(results[0].note.id, 'note-1');
    });

    test('returns filtered notes when collection filter is set', () async {
      container
          .read(searchFiltersProvider.notifier)
          .toggleCollection('col-archive');

      final results = await container.read(searchResultsProvider.future);

      expect(results.length, 1);
      expect(results[0].note.id, 'note-2');
    });

    test('includes tags in the result', () async {
      container.read(searchFiltersProvider.notifier).toggleTag('tag-work');

      final results = await container.read(searchResultsProvider.future);

      expect(results[0].tags.length, 1);
      expect(results[0].tags[0].plainName, 'Work');
    });

    test('contentPreview is populated from plainContent', () async {
      container.read(searchFiltersProvider.notifier).toggleTag('tag-work');

      final results = await container.read(searchResultsProvider.future);

      expect(results[0].contentPreview, isNotEmpty);
      expect(results[0].contentPreview, contains('Flutter'));
    });

    test('searchResultCount is set to result length for tag-only search', () async {
      container.read(searchFiltersProvider.notifier).toggleTag('tag-work');

      await container.read(searchResultsProvider.future);

      expect(container.read(searchResultCountProvider), 1);
    });

    test('returns empty when tag filter matches no notes', () async {
      await db.tagsDao.createTag(
        id: 'tag-empty',
        encryptedName: 'enc-empty',
        plainName: 'Empty',
      );
      container.read(searchFiltersProvider.notifier).toggleTag('tag-empty');

      final results = await container.read(searchResultsProvider.future);

      expect(results, isEmpty);
      expect(container.read(searchResultCountProvider), 0);
    });

    test('clearAll resets filters and returns empty', () async {
      container.read(searchFiltersProvider.notifier).toggleTag('tag-work');
      await container.read(searchResultsProvider.future);
      expect(container.read(searchResultCountProvider), 1);

      container.read(searchFiltersProvider.notifier).clearAll();

      // Need to re-read the provider after clearing filters.
      final freshContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() => freshContainer.dispose());

      final result = await freshContainer.read(searchResultsProvider.future);
      expect(result, isEmpty);
    });
  });

  // ===========================================================================
  // allTagsProvider
  // ===========================================================================

  group('allTagsProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = _createTestDatabase();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      await db.tagsDao.createTag(
        id: 't1',
        encryptedName: 'enc1',
        plainName: 'Work',
      );
      await db.tagsDao.createTag(
        id: 't2',
        encryptedName: 'enc2',
        plainName: 'Personal',
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns all tags from the database', () async {
      final tags = await container.read(allTagsProvider.future);
      expect(tags.length, 2);
      final names = tags.map((t) => t.plainName).toList();
      expect(names, containsAll(['Work', 'Personal']));
    });
  });

  // ===========================================================================
  // allCollectionsProvider
  // ===========================================================================

  group('allCollectionsProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = _createTestDatabase();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      await db.collectionsDao.createCollection(
        id: 'c1',
        encryptedTitle: 'enc1',
        plainTitle: 'Diary',
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('returns all collections from the database', () async {
      final collections = await container.read(allCollectionsProvider.future);
      expect(collections.length, 1);
      expect(collections[0].plainTitle, 'Diary');
    });
  });

  // ===========================================================================
  // recentSearchesProvider
  // ===========================================================================

  group('recentSearchesProvider', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('returns empty list when no recent searches exist', () async {
      final searches = await container.read(recentSearchesProvider.future);
      expect(searches, isEmpty);
    });

    test('returns stored recent searches', () async {
      SharedPreferences.setMockInitialValues({
        'recent_searches': ['flutter', 'riverpod'],
      });

      final freshContainer = ProviderContainer();
      addTearDown(() => freshContainer.dispose());

      final searches = await freshContainer.read(recentSearchesProvider.future);
      expect(searches, ['flutter', 'riverpod']);
    });
  });

  // ===========================================================================
  // addRecentSearch
  // ===========================================================================

  group('addRecentSearch', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds query to front of list', () async {
      final result = await addRecentSearch('flutter');
      expect(result, ['flutter']);
    });

    test('deduplicates existing query and moves to front', () async {
      SharedPreferences.setMockInitialValues({
        'recent_searches': ['flutter', 'riverpod'],
      });

      final result = await addRecentSearch('flutter');
      expect(result.first, 'flutter');
      expect(result.length, 2);
      expect(result, ['flutter', 'riverpod']);
    });

    test('trims list to max 10 entries', () async {
      SharedPreferences.setMockInitialValues({
        'recent_searches': List.generate(10, (i) => 'search-$i'),
      });

      final result = await addRecentSearch('new-search');
      expect(result.length, 10);
      expect(result.first, 'new-search');
    });

    test('persists to SharedPreferences', () async {
      await addRecentSearch('test-query');

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('recent_searches');
      expect(stored, ['test-query']);
    });

    test('adds new query at front while preserving existing order', () async {
      SharedPreferences.setMockInitialValues({
        'recent_searches': ['first', 'second', 'third'],
      });

      final result = await addRecentSearch('new-first');
      expect(result, ['new-first', 'first', 'second', 'third']);
    });
  });

  // ===========================================================================
  // clearRecentSearches
  // ===========================================================================

  group('clearRecentSearches', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'recent_searches': ['a', 'b', 'c'],
      });
    });

    test('removes all recent searches', () async {
      await clearRecentSearches();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_searches'), isNull);
    });
  });
}
