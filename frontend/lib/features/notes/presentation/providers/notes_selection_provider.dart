import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the user is in multi-select mode.
final notesIsSelectionModeProvider = StateProvider<bool>(
  (ref) => false,
);

/// Set of note IDs currently selected in selection mode.
final notesSelectedIdsProvider = StateProvider<Set<String>>(
  (ref) => {},
);
