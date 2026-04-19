import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';
import '../../../core/database/app_database.dart';

// ── Search Filter State ────────────────────────────────

/// Immutable state holding all active search filters.
class SearchFilterState {
  final String query;
  final DateTimeRange? dateRange;
  final Set<String> selectedTagIds;
  final Set<String> selectedCollectionIds;

  const SearchFilterState({
    this.query = '',
    this.dateRange,
    this.selectedTagIds = const {},
    this.selectedCollectionIds = const {},
  });

  SearchFilterState copyWith({
    String? query,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    Set<String>? selectedTagIds,
    Set<String>? selectedCollectionIds,
  }) {
    return SearchFilterState(
      query: query ?? this.query,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      selectedCollectionIds:
          selectedCollectionIds ?? this.selectedCollectionIds,
    );
  }

  /// Whether any filter (besides query text) is active.
  bool get hasActiveFilters =>
      dateRange != null ||
      selectedTagIds.isNotEmpty ||
      selectedCollectionIds.isNotEmpty;

  /// Whether there is enough to perform a search.
  bool get canSearch =>
      query.trim().isNotEmpty ||
      selectedTagIds.isNotEmpty ||
      selectedCollectionIds.isNotEmpty;
}

// ── Search Filters Notifier ────────────────────────────

/// Manages the current search filter state.
class SearchFiltersNotifier extends StateNotifier<SearchFilterState> {
  SearchFiltersNotifier() : super(const SearchFilterState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: range, clearDateRange: range == null);
  }

  void clearDateRange() {
    state = state.copyWith(clearDateRange: true);
  }

  void toggleTag(String tagId) {
    final ids = Set<String>.from(state.selectedTagIds);
    if (ids.contains(tagId)) {
      ids.remove(tagId);
    } else {
      ids.add(tagId);
    }
    state = state.copyWith(selectedTagIds: ids);
  }

  void toggleCollection(String collectionId) {
    final ids = Set<String>.from(state.selectedCollectionIds);
    if (ids.contains(collectionId)) {
      ids.remove(collectionId);
    } else {
      ids.add(collectionId);
    }
    state = state.copyWith(selectedCollectionIds: ids);
  }

  void removeTag(String tagId) {
    final ids = Set<String>.from(state.selectedTagIds)..remove(tagId);
    state = state.copyWith(selectedTagIds: ids);
  }

  void removeCollection(String collectionId) {
    final ids = Set<String>.from(state.selectedCollectionIds)
      ..remove(collectionId);
    state = state.copyWith(selectedCollectionIds: ids);
  }

  void setSelectedTagIds(Set<String> tagIds) {
    state = state.copyWith(selectedTagIds: tagIds);
  }

  void setSelectedCollectionIds(Set<String> collectionIds) {
    state = state.copyWith(selectedCollectionIds: collectionIds);
  }

  void clearAll() {
    state = const SearchFilterState();
  }
}

final searchFiltersProvider =
    StateNotifierProvider<SearchFiltersNotifier, SearchFilterState>(
  (ref) => SearchFiltersNotifier(),
);

// ── Search Results ─────────────────────────────────────

/// A single search result with associated metadata.
class AdvancedSearchResult {
  final Note note;
  final List<Tag> tags;
  final String contentPreview;

  AdvancedSearchResult({
    required this.note,
    required this.tags,
    required this.contentPreview,
  });
}

/// Performs the filtered search and returns results.
final searchResultsProvider =
    FutureProvider<List<AdvancedSearchResult>>((ref) async {
  final filters = ref.watch(searchFiltersProvider);
  if (!filters.canSearch) return [];

  final db = ref.read(databaseProvider);

  final notes = await db.notesDao.searchNotesFiltered(
    query: filters.query.trim().isEmpty ? null : filters.query,
    startDate: filters.dateRange?.start,
    endDate: filters.dateRange?.end,
    tagIds:
        filters.selectedTagIds.isEmpty ? null : filters.selectedTagIds.toList(),
    collectionIds: filters.selectedCollectionIds.isEmpty
        ? null
        : filters.selectedCollectionIds.toList(),
  );

  // Store the total count for "showing X of Y" display.
  // For text queries, use the FTS5 count. For filter-only queries, use the
  // result length (no FTS5 involved).
  if (filters.query.trim().isNotEmpty) {
    final count = await db.notesDao.countSearchResults(filters.query);
    ref.read(searchResultCountProvider.notifier).state = count;
  } else {
    ref.read(searchResultCountProvider.notifier).state = notes.length;
  }

  // Load tags and build preview for each note.
  final results = <AdvancedSearchResult>[];
  for (final note in notes) {
    final tags = await db.tagsDao.getTagsForNote(note.id);
    final content = note.plainContent ?? '';
    final preview = _buildPreview(content, filters.query);
    results.add(AdvancedSearchResult(
      note: note,
      tags: tags,
      contentPreview: preview,
    ));
  }

  return results;
});

/// Total match count for the current search query (before pagination).
/// Used to display "showing X of Y results" in the search UI.
final searchResultCountProvider = StateProvider<int>((ref) => 0);

/// Build a short preview of the content, trying to center it around
/// the first occurrence of [query]. Falls back to the first 150 chars.
String _buildPreview(String content, String query) {
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

// ── Tags & Collections for Filter Pickers ──────────────

/// All tags for the tag filter picker.
final allTagsProvider = FutureProvider<List<Tag>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.tagsDao.getAllTags();
});

/// All collections for the collection filter picker.
final allCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.collectionsDao.getAllCollections();
});

// ── Recent Searches ────────────────────────────────────

const _recentSearchesKey = 'recent_searches';
const _maxRecentSearches = 10;

/// Loads recent search queries from SharedPreferences.
final recentSearchesProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_recentSearchesKey) ?? [];
});

/// Adds a search query to the recent searches list (deduplicating and trimming
/// to [_maxRecentSearches] entries). Returns the updated list.
Future<List<String>> addRecentSearch(String query) async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getStringList(_recentSearchesKey) ?? [];
  // Remove duplicates, add to front, trim to max.
  final updated = [query, ...existing.where((q) => q != query)];
  final trimmed = updated.take(_maxRecentSearches).toList();
  await prefs.setStringList(_recentSearchesKey, trimmed);
  return trimmed;
}

/// Clears all recent searches from SharedPreferences.
Future<void> clearRecentSearches() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_recentSearchesKey);
}
