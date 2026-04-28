import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/database/app_database.dart';
import '../../../../main.dart';

/// The current search query text.
final notesSearchQueryProvider = StateProvider<String>(
  (ref) => '',
);

/// Whether the search bar is visible.
final notesIsSearchingProvider = StateProvider<bool>(
  (ref) => false,
);

/// FTS5 search results for the current search query.
///
/// This provider debounces the search by 300ms. When the query is empty,
/// the result is an empty list.
final notesSearchResultsProvider = FutureProvider<List<Note>>((ref) async {
  final query = ref.watch(notesSearchQueryProvider);
  if (query.isEmpty) return [];

  // Debounce: wait for the provider to stabilize for 300ms.
  // The watch() call above will cause this provider to recompute whenever
  // the query changes. By adding an artificial delay, we effectively debounce.
  await Future.delayed(AppDurations.debounce);

  // After the delay, check if the query is still the same. If another
  // computation started (query changed again), this one will be cancelled
  // automatically by Riverpod.
  final db = ref.read(databaseProvider);
  return db.notesDao.searchNotes(query);
});

/// Manages the search query with debouncing. Call [onSearchChanged] from
/// the TextField's onChanged callback.
class NotesSearchNotifier extends StateNotifier<String> {
  Timer? _debounceTimer;

  NotesSearchNotifier() : super('');

  /// Update the search query with a built-in debounce.
  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppDurations.debounce, () {
      state = query;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for the debounced search query.
final notesSearchNotifierProvider =
    StateNotifierProvider<NotesSearchNotifier, String>(
  (ref) => NotesSearchNotifier(),
);
