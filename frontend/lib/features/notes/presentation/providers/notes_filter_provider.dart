import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active sort option for the notes list.
///
/// Values correspond to the PopupMenuButton entries in the notes list screen:
/// 'updated_newest', 'updated_oldest', 'created_newest', 'created_oldest',
/// 'title_az', 'custom'.
final notesSortOptionProvider = StateProvider<String>(
  (ref) => 'updated_newest',
);

/// Active status filter (null = no filter).
///
/// When set, only notes with a matching `status` property are shown.
final notesStatusFilterProvider = StateProvider<String?>(
  (ref) => null,
);

/// Active priority filter (null = no filter).
///
/// When set, only notes with a matching `priority` property are shown.
final notesPriorityFilterProvider = StateProvider<String?>(
  (ref) => null,
);

/// Active collection filter (null = no filter).
///
/// When set, only notes belonging to the specified collection are shown.
final notesCollectionFilterProvider = StateProvider<String?>(
  (ref) => null,
);
