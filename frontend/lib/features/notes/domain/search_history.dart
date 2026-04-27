import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for storing search history.
const _searchHistoryKey = 'search_history_v2';

/// Maximum number of entries to keep in search history.
const maxSearchHistoryEntries = 20;

/// Manages recent search queries persisted in SharedPreferences.
class SearchHistory {
  static const _key = _searchHistoryKey;
  final SharedPreferences _prefs;

  SearchHistory(this._prefs);

  /// Returns the list of recent searches, most recent first.
  List<String> get entries {
    return _prefs.getStringList(_key) ?? [];
  }

  /// Adds a query to the front of the history list.
  /// Deduplicates: if the query already exists, it moves to the front.
  /// Trims to [maxSearchHistoryEntries] entries.
  Future<void> add(String query) async {
    if (query.trim().isEmpty) return;
    final existing = entries;
    final updated = [
      query,
      ...existing.where((q) => q != query),
    ];
    final trimmed = updated.take(maxSearchHistoryEntries).toList();
    await _prefs.setStringList(_key, trimmed);
  }

  /// Removes a specific query from the history.
  Future<void> remove(String query) async {
    final existing = entries;
    final updated = existing.where((q) => q != query).toList();
    await _prefs.setStringList(_key, updated);
  }

  /// Clears all search history.
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers for search history
// ---------------------------------------------------------------------------

/// Provides a [SearchHistory] instance backed by SharedPreferences.
final searchHistoryProvider = FutureProvider<SearchHistory>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return SearchHistory(prefs);
});

/// Provides the current list of recent search entries.
/// Refresh this provider after calling [SearchHistory.add] or [SearchHistory.clear].
final searchHistoryEntriesProvider = FutureProvider<List<String>>((ref) async {
  final historyAsync = ref.watch(searchHistoryProvider);
  return historyAsync.when(
    data: (history) => history.entries,
    loading: () => [],
    error: (_, __) => [],
  );
});
