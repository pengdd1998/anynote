import 'dart:async';
import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/error/error.dart' show ErrorDisplay;
import '../../../core/theme/app_animation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/paper_tokens.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/note_properties_dao.dart';
import '../../../core/import/apple_notes_import.dart';
import '../../../core/import/import_models.dart';
import '../../../core/import/markdown_import_service.dart';
import '../../../core/import/text_import.dart';
import '../../../core/navigation/nav_guard.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../../core/widgets/color_picker_sheet.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/master_detail_layout.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/sidebar_provider.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../main.dart';
import '../../settings/data/settings_providers.dart';
import 'widgets/command_palette.dart';
import 'widgets/template_picker_sheet.dart';
import 'widgets/collection_picker_sheet.dart';
import 'widgets/dismissible_note_card.dart';
import 'widgets/export_sheet.dart';
import 'widgets/orphaned_notes_sheet.dart';
import 'widgets/split_note_picker_sheet.dart';
import 'widgets/split_view_pane.dart';
import 'widgets/inline_note_detail.dart';
import 'widgets/notes_batch_actions.dart';
import 'widgets/notes_filter_sheet.dart';
import 'widgets/staggered_card_entrance.dart';

/// Page size for paginated note loading.
/// 50 items balances smooth scrolling with low memory usage.
/// At ~200 bytes per Note object in memory, 50 notes = ~10 KB.
const _kPageSize = 50;

/// Which import source the user picked from the import bottom sheet.
enum ImportType { markdown, text, appleNotes }

class NotesListScreen extends ConsumerStatefulWidget {
  /// When false, skips the initial Drift watch subscription in initState.
  /// Use this in widget tests to avoid timer leaks from Drift's
  /// StreamQueryStore that the test framework cannot drain.
  @visibleForTesting
  final bool autoLoad;

  const NotesListScreen({super.key, this.autoLoad = true});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen>
    with TickerProviderStateMixin {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Timer? _debounceTimer;

  bool _isGridView = true;
  String _sortOption = 'updated_newest';

  /// Whether the current sort mode is custom (drag-and-drop reorder).
  bool get _isCustomSort => _sortOption == 'custom';

  /// Responsive max card width: 360px on mobile, smaller on wider screens
  /// to allow more columns.
  double _maxCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width > 1200) return 280;
    if (width > 800) return 320;
    return 360;
  }

  /// Accumulated list of notes loaded so far for infinite scroll.
  List<Note> _notes = [];

  /// Whether there are more notes to load.
  bool _hasMore = true;

  /// Whether a page fetch is currently in progress.
  bool _isLoadingPage = false;

  /// Current offset for the next page.
  int _currentOffset = 0;

  /// Reactive stream subscription for the current page batch.
  StreamSubscription<List<Note>>? _pageSubscription;

  /// Cache of note ID -> tags for displaying tag chips.
  final Map<String, List<Tag>> _tagsCache = {};

  /// Maximum number of entries in [_tagsCache] before eviction.
  static const int _maxTagsCacheSize = 200;

  /// Cache of note ID -> locked state for displaying lock icons.
  final Map<String, bool> _lockedCache = {};

  /// Scroll controller for detecting near-bottom in infinite scroll.
  final ScrollController _scrollController = ScrollController();

  /// Selected note ID for the master-detail layout on desktop.
  /// Null on phone layout.
  String? _selectedNoteId;

  /// Returns true when the screen is wide enough for side-by-side layout.
  bool get _isWideScreen {
    if (!mounted) return false;
    return MediaQuery.of(context).size.width >= 1024;
  }

  // --- Search infinite scroll state ---
  List<Note> _searchResults = [];
  bool _hasMoreSearchResults = true;
  bool _isLoadingMoreSearch = false;

  // --- Staggered entrance animation state ---

  /// Maximum number of cards to animate on entrance.
  static const int _kMaxAnimatedCards = 20;

  /// Stagger delay per card in milliseconds.
  static const int _kStaggerDelayMs = 30;

  /// Track whether the initial entrance animation has played.
  bool _hasPlayedEntrance = false;

  // --- Batch selection state ---

  /// Whether the user is in multi-select mode.
  bool _isSelectionMode = false;

  /// Set of note IDs currently selected in selection mode.
  Set<String> _selectedNoteIds = {};

  // --- Property filter state ---

  /// Active status filter (null = no filter).
  String? _statusFilter;

  /// Active priority filter (null = no filter).
  String? _priorityFilter;

  /// Active tag filter for quick filter chips (null = show all).
  String? _quickTagFilter;

  /// Active tag filter (null = no filter, Set<String> = selected tag IDs).
  Set<String>? _tagFilter;

  /// All tags loaded for the tag filter UI.
  List<Tag> _allTags = [];

  /// Subscription to all tags for the filter.
  StreamSubscription<List<Tag>>? _tagsSubscription;

  /// Cache of note ID -> properties for filtering.
  final Map<String, List<NoteProperty>> _propertiesCache = {};

  /// Maximum number of entries in [_propertiesCache] before eviction.
  static const int _maxPropertiesCacheSize = 200;

  // --- Split view state ---

  /// Note ID displayed in the secondary (right) pane during split view.
  /// Null means split view is not active.
  String? _splitViewNoteId;

  /// Title of the note in the secondary pane (for the header bar).
  String? _splitViewNoteTitle;

  /// Cached result of property filtering, rebuilt only when filter inputs change.
  List<Note> _filteredNotes = [];

  /// Tracks the filter signature used to produce [_filteredNotes].
  /// When this no longer matches the current filters, the cache is stale.
  String? _lastFilterSignature;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.autoLoad) {
      _loadInitialNotes();
      // Load all tags for the tag filter UI.
      final db = ref.read(databaseProvider);
      _tagsSubscription = db.tagsDao.watchAllTags().listen((tags) {
        if (mounted) {
          setState(() => _allTags = tags);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageSubscription?.cancel();
    _tagsSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LRU cache helper
  // ---------------------------------------------------------------------------

  /// Retrieve a value from [cache], re-inserting it to approximate LRU eviction.
  /// LinkedHashMap iteration order is insertion order, so re-inserting moves
  /// the entry to the end (most recently used).
  T? _cacheGet<T>(Map<String, T> cache, String key) {
    final value = cache.remove(key);
    if (value != null) cache[key] = value;
    return value;
  }

  // ---------------------------------------------------------------------------
  // Property filtering
  // ---------------------------------------------------------------------------

  /// Apply property filters to the notes list.
  ///
  /// Uses batch property loading to avoid N+1 queries when filtering
  /// by status or priority.
  Future<List<Note>> _applyPropertyFilters(
    List<Note> notes,
    AppDatabase db,
  ) async {
    if (_statusFilter == null &&
        _priorityFilter == null &&
        (_tagFilter == null || _tagFilter!.isEmpty)) {
      return notes;
    }

    // Batch-load properties for all notes that are not already cached.
    final uncachedIds = notes
        .where((n) => !_propertiesCache.containsKey(n.id))
        .map((n) => n.id)
        .toList();

    if (uncachedIds.isNotEmpty) {
      final batchProps =
          await db.notesDao.batchGetPropertiesForNotes(uncachedIds);
      _propertiesCache.addAll(batchProps);
      // Evict oldest entries when the cache exceeds the max size.
      while (_propertiesCache.length > _maxPropertiesCacheSize) {
        _propertiesCache.remove(_propertiesCache.keys.first);
      }
    }

    final filtered = <Note>[];

    for (final note in notes) {
      final properties = _cacheGet(_propertiesCache, note.id) ?? [];

      bool matchesStatus = true;
      bool matchesPriority = true;

      if (_statusFilter != null) {
        matchesStatus = properties.any(
          (p) =>
              p.key == BuiltInProperties.status && p.valueText == _statusFilter,
        );
      }

      if (_priorityFilter != null) {
        matchesPriority = properties.any(
          (p) =>
              p.key == BuiltInProperties.priority &&
              p.valueText == _priorityFilter,
        );
      }

      if (matchesStatus && matchesPriority) {
        filtered.add(note);
      }
    }

    // Apply tag filter as a second pass using the tags cache.
    if (_tagFilter != null && _tagFilter!.isNotEmpty) {
      final tagFiltered = <Note>[];
      for (final note in filtered) {
        final noteTags = _cacheGet(_tagsCache, note.id) ?? [];
        final noteTagIds = noteTags.map((t) => t.id).toSet();
        if (noteTagIds.intersection(_tagFilter!).isNotEmpty) {
          tagFiltered.add(note);
        }
      }
      return tagFiltered;
    }

    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Notes pagination
  // ---------------------------------------------------------------------------

  /// Load the first page of notes and set up a reactive watch.
  void _loadInitialNotes() {
    _currentOffset = 0;
    _hasMore = true;
    _isLoadingPage = false;
    _notes.clear();
    _pageSubscription?.cancel();
    _hasPlayedEntrance = false;

    final db = ref.read(databaseProvider);

    // Watch the first page reactively so pinned/deleted changes propagate.
    _pageSubscription =
        db.notesDao.watchPaginatedNotes(_kPageSize, 0).listen((firstPage) {
      if (!mounted) return;

      db.notesDao.countNotes().then((total) {
        if (!mounted) return;
        setState(() {
          _notes = firstPage;
          _currentOffset = firstPage.length;
          _hasMore = firstPage.length < total;
          _isLoadingPage = false;
          // Force re-application of property filters since the underlying
          // note list changed (new notes, updated notes, deleted notes).
          _lastFilterSignature = null;
        });

        _batchLoadTagsAndLocks(firstPage, db);
      });
    });
  }

  /// Load the next page of notes (one-shot query, not reactive).
  Future<void> _loadMoreNotes() async {
    if (_isLoadingPage || !_hasMore) return;

    setState(() => _isLoadingPage = true);

    final db = ref.read(databaseProvider);
    final newNotes =
        await db.notesDao.getPaginatedNotes(_kPageSize, _currentOffset);

    if (!mounted) return;

    // Avoid duplicates (can happen if data changed between loads).
    final existingIds = _notes.map((n) => n.id).toSet();
    final uniqueNewNotes =
        newNotes.where((n) => !existingIds.contains(n.id)).toList();

    setState(() {
      _notes.addAll(uniqueNewNotes);
      _currentOffset += newNotes.length;
      _hasMore = newNotes.length == _kPageSize;
      _isLoadingPage = false;
    });

    _batchLoadTagsAndLocks(uniqueNewNotes, db);
  }

  /// Reset pagination state and reload from scratch.
  /// Re-triggers the staggered entrance animation.
  void _resetAndReload() {
    _pageSubscription?.cancel();
    _tagsCache.clear();
    _lockedCache.clear();
    _loadInitialNotes();
  }

  // ---------------------------------------------------------------------------
  // Search pagination
  // ---------------------------------------------------------------------------

  /// Called when the search text changes. Debounces FTS5 queries by 300ms.
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    setState(() {
      _searchQuery = query;
      _searchResults.clear();
      _hasMoreSearchResults = true;
      _isLoadingMoreSearch = false;
    });

    if (query.isEmpty) return;

    _debounceTimer = Timer(AppDurations.debounce, () {
      if (!mounted) return;
      final db = ref.read(databaseProvider);

      db.notesDao.searchNotesPaginated(query, _kPageSize, 0).then((results) {
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _hasMoreSearchResults = results.length == _kPageSize;
        });
        _batchLoadTagsAndLocks(results, db);
      });
    });
  }

  /// Load more search results for infinite scroll during search.
  Future<void> _loadMoreSearchResults() async {
    if (_isLoadingMoreSearch ||
        !_hasMoreSearchResults ||
        _searchQuery.isEmpty) {
      return;
    }

    setState(() => _isLoadingMoreSearch = true);

    final db = ref.read(databaseProvider);
    final newResults = await db.notesDao.searchNotesPaginated(
      _searchQuery,
      _kPageSize,
      _searchResults.length,
    );

    if (!mounted) return;

    final existingIds = _searchResults.map((n) => n.id).toSet();
    final uniqueNew =
        newResults.where((n) => !existingIds.contains(n.id)).toList();

    setState(() {
      _searchResults.addAll(uniqueNew);
      _hasMoreSearchResults = newResults.length == _kPageSize;
      _isLoadingMoreSearch = false;
    });

    _batchLoadTagsAndLocks(uniqueNew, db);
  }

  // ---------------------------------------------------------------------------
  // Scroll detection
  // ---------------------------------------------------------------------------

  /// Scroll listener: load more when user is near the bottom (80%).
  void _onScroll() {
    if (_isLoadingPage || _isLoadingMoreSearch) return;

    final currentOffset = _scrollController.position.pixels;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final nearBottom = currentOffset >= maxScroll * 0.8;

    if (!nearBottom) return;

    if (_isSearching && _searchQuery.isNotEmpty) {
      _loadMoreSearchResults();
    } else {
      _loadMoreNotes();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Load lock state for a single note and cache it.
  Future<void> _loadLockForNote(String noteId, AppDatabase db) async {
    if (_lockedCache.containsKey(noteId)) return;
    final locked = await db.notePropertiesDao.isNoteLocked(noteId);
    if (mounted) {
      setState(() {
        _lockedCache[noteId] = locked;
      });
    }
  }

  /// Batch-load tags and lock states for a list of notes.
  ///
  /// Uses the DAO's batch methods to avoid N+1 queries. Only loads
  /// data for notes that are not already cached.
  Future<void> _batchLoadTagsAndLocks(
    List<Note> notes,
    AppDatabase db,
  ) async {
    if (notes.isEmpty) return;

    // Determine which notes need tag, lock, and property loading.
    final notesNeedingTags =
        notes.where((n) => !_tagsCache.containsKey(n.id)).toList();
    final notesNeedingLocks =
        notes.where((n) => !_lockedCache.containsKey(n.id)).toList();
    final notesNeedingProperties =
        notes.where((n) => !_propertiesCache.containsKey(n.id)).toList();

    if (notesNeedingTags.isEmpty &&
        notesNeedingLocks.isEmpty &&
        notesNeedingProperties.isEmpty) return;

    // Run all batch queries in parallel.
    final results = await Future.wait([
      if (notesNeedingTags.isNotEmpty)
        db.notesDao.batchGetTagsForNotes(
          notesNeedingTags.map((n) => n.id).toList(),
        )
      else
        Future.value(<String, List<Tag>>{}),
      if (notesNeedingLocks.isNotEmpty)
        db.notesDao.batchGetLocksForNotes(
          notesNeedingLocks.map((n) => n.id).toList(),
        )
      else
        Future.value(<String, bool>{}),
      if (notesNeedingProperties.isNotEmpty)
        db.notesDao.batchGetPropertiesForNotes(
          notesNeedingProperties.map((n) => n.id).toList(),
        )
      else
        Future.value(<String, List<NoteProperty>>{}),
    ]);

    if (!mounted) return;

    final tagsMap = results[0] as Map<String, List<Tag>>;
    final locksMap = results[1] as Map<String, bool>;
    final propsMap = results[2] as Map<String, List<NoteProperty>>;

    setState(() {
      _tagsCache.addAll(tagsMap);
      while (_tagsCache.length > _maxTagsCacheSize) {
        _tagsCache.remove(_tagsCache.keys.first);
      }
      _lockedCache.addAll(locksMap);
      _propertiesCache.addAll(propsMap);
      while (_propertiesCache.length > _maxPropertiesCacheSize) {
        _propertiesCache.remove(_propertiesCache.keys.first);
      }
    });
  }

  /// Sort notes according to the current sort option.
  /// Pinned notes always come first regardless of sort order.
  List<Note> _sortNotes(List<Note> notes) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = List<Note>.from(notes);
    final untitled = l10n.untitled;

    switch (_sortOption) {
      case 'updated_newest':
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case 'updated_oldest':
        sorted.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case 'created_newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'created_oldest':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'title_az':
        // Notes have no stored title — sort by the first line of content
        // (the list label), falling back to a legacy title then "Untitled".
        String label(Note n) {
          final content = n.plainContent;
          if (content != null && content.trim().isNotEmpty) {
            final firstLine = content.trim().split('\n').first.trim();
            if (firstLine.isNotEmpty) return firstLine;
          }
          return n.plainTitle ?? untitled;
        }
        sorted.sort((a, b) {
          final ta = label(a);
          final tb = label(b);
          return ta.toLowerCase().compareTo(tb.toLowerCase());
        });
        break;
      case 'custom':
        // For custom sort, order by sortOrder field then by updatedAt as tiebreaker.
        sorted.sort((a, b) {
          final cmp = a.sortOrder.compareTo(b.sortOrder);
          if (cmp != 0) return cmp;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        break;
    }

    // Always move pinned notes to the top.
    sorted.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });

    return sorted;
  }

  /// Handle reorder in custom sort mode.
  /// Updates the local list immediately and persists sort orders to the DB.
  Future<void> _onReorder(List<Note> notes, int oldIndex, int newIndex) async {
    // Adjust newIndex when moving downward because the list shrinks by one.
    if (oldIndex < newIndex) newIndex -= 1;

    setState(() {
      final note = notes.removeAt(oldIndex);
      notes.insert(newIndex, note);
    });

    // Persist the new order to the database.
    final db = ref.read(databaseProvider);
    final reorderedIds = notes.map((n) => n.id).toList();
    await db.notesDao.reorderNotes(reorderedIds);
  }

  // ---------------------------------------------------------------------------
  // Wordmark
  // ---------------------------------------------------------------------------

  /// Handwritten "AnyNote" wordmark with a small golden sparkle at its
  /// top-right corner (per the design mockup).
  Widget _buildWordmark() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AnyNote',
          style: AppTextStyles.handwritingTitle.copyWith(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(width: AppSpacing.s4),
        // Golden sparkle hugging the wordmark's top-right corner.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s2),
          child: Text(
            '\u2726', // four-pointed sparkle
            style: AppTextStyles.caption.copyWith(
              fontSize: 14,
              color: AppColors.warning,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Filter chips
  // ---------------------------------------------------------------------------

  /// Decorative emoji shown before the "All" filter chip label.
  static const String _allFilterEmoji = '\u{1F4DA}'; // books

  /// Emoji palette cycled for tags without a keyword match.
  static const List<String> _fallbackTagEmojis = [
    '\u{1F4A1}', // light bulb
    '\u{1F4BC}', // briefcase
    '\u{1F33F}', // herb
    '\u2728', // sparkles
    '\u{1F3AF}', // dart
    '\u{1F4D6}', // open book
  ];

  /// Returns a decorative emoji for a tag name. Well-known keywords map to a
  /// matching emoji; anything else cycles the fallback palette deterministically.
  String _emojiForTag(String name) {
    final n = name.toLowerCase();
    if (n.contains('idea')) return '\u{1F4A1}'; // light bulb
    if (n.contains('work') || n.contains('project') || n.contains('job')) {
      return '\u{1F4BC}'; // briefcase
    }
    if (n.contains('personal') || n.contains('life') || n.contains('journal')) {
      return '\u{1F33F}'; // herb
    }
    if (n.contains('todo') || n.contains('task')) return '\u2705'; // check
    if (n.contains('read') || n.contains('book')) return '\u{1F4D6}'; // book
    if (n.contains('travel') || n.contains('trip')) return '\u2708\uFE0F'; // plane
    return _fallbackTagEmojis[name.hashCode.abs() % _fallbackTagEmojis.length];
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Unselected: white card surface with a hairline warm border.
    final unselectedBg =
        isDark ? AppColors.darkInputFill : AppColors.lightCardBg;
    final unselectedBorder =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final unselectedText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    // Show first 8 tags, then a "+N more" chip.
    final visibleTags = _allTags.take(8).toList();
    final remaining = _allTags.length - visibleTags.length;

    Widget buildChip({
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.s8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppAnimation.short,
            curve: AppAnimation.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              // Selected: soft periwinkle tint, no border (mockup style).
              color: isSelected
                  ? AppColors.primarySoft
                  : unselectedBg,
              borderRadius: AppRadius.pillBorder,
              border: isSelected
                  ? null
                  : Border.all(color: unselectedBorder, width: 1),
            ),
            child: Text(
              label,
              style: AppTextStyles.filterChip.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primaryText : unselectedText,
              ),
            ),
          ),
        ),
      );
    }

    // Full width so a single short chip row hugs the left edge instead of
    // centering inside the body column (design mockup: chips start left).
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          buildChip(
            label: '$_allFilterEmoji ${l10n.filterAll}',
            isSelected: _quickTagFilter == null && (_tagFilter == null || _tagFilter!.isEmpty),
            onTap: () => setState(() {
              _quickTagFilter = null;
              _tagFilter = null;
            }),
          ),
          // Tag chips
          ...visibleTags.map((tag) {
            final isSelected = _quickTagFilter == tag.id;
            final tagName = tag.plainName ?? tag.id;
            return buildChip(
              label: '${_emojiForTag(tagName)} $tagName',
              isSelected: isSelected,
              onTap: () => setState(() {
                if (_quickTagFilter == tag.id) {
                  _quickTagFilter = null;
                  _tagFilter = null;
                } else {
                  _quickTagFilter = tag.id;
                  _tagFilter = {tag.id};
                }
              }),
            );
          }),
          // "+N more" chip
          if (remaining > 0)
            buildChip(
              label: '+$remaining',
              isSelected: false,
              onTap: () => NotesFilterSheet.show(
                context: context,
                statusFilter: _statusFilter,
                priorityFilter: _priorityFilter,
                tagFilter: _tagFilter,
                allTags: _allTags,
                onStatusChanged: (status) =>
                    setState(() => _statusFilter = status),
                onPriorityChanged: (priority) =>
                    setState(() => _priorityFilter = priority),
                onTagChanged: (tagId) {
                  setState(() {
                    _quickTagFilter = null;
                    _tagFilter ??= {};
                    if (_tagFilter!.contains(tagId)) {
                      _tagFilter!.remove(tagId);
                      if (_tagFilter!.isEmpty) _tagFilter = null;
                    } else {
                      _tagFilter!.add(tagId);
                    }
                  });
                },
                onClearAll: () => setState(() {
                  _statusFilter = null;
                  _priorityFilter = null;
                  _tagFilter = null;
                  _quickTagFilter = null;
                }),
              ),
            ),
        ],
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final wideScreen = AdaptiveScaffold.isDesktop(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Paper tokens carry the desk color — slightly deeper than the app
      // background so the sticky-note sheets pop (mockup page surface).
      backgroundColor: PaperTokens.of(context).desk,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: _isSearching
            ? Semantics(
                label: l10n.searchNotesTooltip,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchNotes,
                    border: InputBorder.none,
                  ),
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                ),
              )
            : _isSelectionMode
                ? Text(
                    l10n.selectedNotes(_selectedNoteIds.length),
                    style: AppTextStyles.title,
                  )
                : _buildWordmark(),
        actions: [
          if (_isSearching && !_isSelectionMode) ...[
            IconButton(
              icon: const Icon(AppIcons.close),
              tooltip: l10n.close,
              onPressed: _exitSearchMode,
            ),
          ] else if (_isSelectionMode) ...[
            // Select/Deselect All
            TextButton(
              onPressed: _selectedNoteIds.length == _notes.length
                  ? _deselectAllNotes
                  : _selectAllNotes,
              child: Text(
                _selectedNoteIds.length == _notes.length
                    ? l10n.deselectAll
                    : l10n.selectAll,
              ),
            ),
            // Done button to exit selection mode
            IconButton(
              icon: const Icon(AppIcons.close),
              tooltip: l10n.done,
              onPressed: _exitSelectionMode,
            ),
          ] else ...[
            // Create note button (moved from FAB to app bar)
            IconButton(
              icon: const Icon(AppIcons.add),
              tooltip: l10n.createNewNote,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/notes/new');
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showCreateOptions(context);
              },
            ),
            // "More" overflow menu with all features
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.moreActions,
              onSelected: (value) {
                switch (value) {
                  // Sort options
                  case 'sort_updated_newest':
                    setState(() => _sortOption = 'updated_newest');
                  case 'sort_updated_oldest':
                    setState(() => _sortOption = 'updated_oldest');
                  case 'sort_created_newest':
                    setState(() => _sortOption = 'created_newest');
                  case 'sort_created_oldest':
                    setState(() => _sortOption = 'created_oldest');
                  case 'sort_title_az':
                    setState(() => _sortOption = 'title_az');
                  case 'sort_custom':
                    setState(() => _sortOption = 'custom');
                  // View toggles
                  case 'toggle_view':
                    setState(() => _isGridView = !_isGridView);
                  case 'search':
                    setState(() {
                      _isSearching = true;
                      _pageSubscription?.cancel();
                    });
                  // Other actions
                  case 'trash':
                    context.push('/trash');
                  case 'command_palette':
                    showCommandPalette();
                  case 'select_notes':
                    setState(() => _isSelectionMode = true);
                  case 'advanced_search':
                    context.push('/search');
                  case 'collections':
                    context.push('/collections');
                  case 'graph':
                    context.push('/notes/graph');
                  case 'dashboard':
                    context.push('/notes/dashboard');
                  case 'statistics':
                    context.push('/notes/statistics');
                  case 'daily':
                    context.push('/notes/daily');
                  case 'reminders':
                    context.push('/notes/reminders');
                  case 'orphaned':
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => const OrphanedNotesSheet(),
                    );
                  case 'snippets':
                    context.push('/snippets');
                  case 'import':
                    _showImportSheet(context);
                }
              },
              itemBuilder: (context) => [
                // --- View section (top priority) ---
                PopupMenuItem(
                  value: 'toggle_view',
                  child: ListTile(
                    leading: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                    title: Text(_isGridView ? l10n.listView : l10n.gridView),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    leading: const Icon(AppIcons.search),
                    title: Text(l10n.searchNotes),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                // --- Sort section ---
                _buildSortMenuItem('sort_updated_newest', l10n.updatedNewest, AppIcons.sort),
                _buildSortMenuItem('sort_updated_oldest', l10n.updatedOldest, AppIcons.sort),
                _buildSortMenuItem('sort_created_newest', l10n.createdNewest, AppIcons.sort),
                _buildSortMenuItem('sort_created_oldest', l10n.createdOldest, AppIcons.sort),
                _buildSortMenuItem('sort_title_az', l10n.titleAZ, AppIcons.sort),
                _buildSortMenuItem('sort_custom', l10n.sortCustom, AppIcons.sort),
                const PopupMenuDivider(),
                // --- Quick actions ---
                PopupMenuItem(
                  value: 'trash',
                  child: ListTile(
                    leading: const Icon(AppIcons.deleteOutline),
                    title: Text(l10n.trash),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                // Command palette is a desktop (Ctrl+K) quick-navigation
                // tool — AnyNote on phones has no use for it, so the menu
                // entry only appears on desktop platforms.
                if (PlatformUtils.isDesktop)
                  PopupMenuItem(
                    value: 'command_palette',
                    child: ListTile(
                      leading: const Icon(AppIcons.keyboard),
                      title: Text(l10n.commandPalette),
                      subtitle: const Text('Ctrl+K'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: 'select_notes',
                  child: ListTile(
                    leading: const Icon(AppIcons.checkCircle),
                    title: Text(l10n.selectNotes),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_isSearching)
                  PopupMenuItem(
                    value: 'advanced_search',
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: Text(l10n.advancedSearch),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuDivider(),
                // --- View section ---
                PopupMenuItem(
                  value: 'collections',
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(l10n.collections),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'graph',
                  child: ListTile(
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text(l10n.knowledgeGraph),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'dashboard',
                  child: ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: Text(l10n.propertiesDashboard),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'statistics',
                  child: ListTile(
                    leading: const Icon(Icons.bar_chart_outlined),
                    title: Text(l10n.statistics),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'daily',
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(l10n.dailyNotes),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                // --- Tools section ---
                PopupMenuItem(
                  value: 'reminders',
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(l10n.reminders),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'orphaned',
                  child: ListTile(
                    leading: const Icon(Icons.scatter_plot_outlined),
                    title: Text(l10n.orphanedNotes),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'snippets',
                  child: ListTile(
                    leading: const Icon(Icons.code_outlined),
                    title: Text(l10n.snippets),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                // --- Import/Export section ---
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: Text(l10n.importNotes),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
          children: [
            // Offline banner at the top
            const OfflineBanner(),
            // Search bar (persistent, below AppBar)
            if (!_isSelectionMode && !_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.s4,
                  AppSpacing.md,
                  0,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchNotes,
                    hintStyle: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    prefixIcon: Icon(
                      AppIcons.search,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkInputFill
                        : AppColors.lightInputFill,
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.pillBorder,
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    isDense: true,
                  ),
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  onTap: () {
                    if (!_isSearching) {
                      setState(() {
                        _isSearching = true;
                        _pageSubscription?.cancel();
                      });
                    }
                  },
                  onChanged: _onSearchChanged,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                ),
              ),
            // Filter chips row
            if (!_isSelectionMode && !_isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.s8,
                  AppSpacing.md,
                  0,
                ),
                child: _buildFilterChips(l10n),
              ),
            // Batch action bar (shown when in selection mode)
            if (_isSelectionMode)
              NotesBatchActionBar(
                selectedNoteIds: _selectedNoteIds,
                notes: _notes,
                onTogglePin: () => _batchTogglePin(db, l10n),
                onColor: () => _batchColor(db, l10n),
                onLock: () => _batchLock(db, l10n),
                onDelete: () => _batchDelete(db, l10n),
                onExport: _showExportSheet,
                onCompare:
                    _selectedNoteIds.length == 2 ? _compareSelectedNotes : null,
                onMoveToCollection: () =>
                    _moveToCollection(db, l10n, _selectedNoteIds.toList()),
                onAddTags: () => _batchAddTags(db, l10n),
              ),
            // Property filter bar (only visible when filters are active)
            if (!_isSearching && (_statusFilter != null || _priorityFilter != null || (_tagFilter != null && _tagFilter!.isNotEmpty)))
              NotesFilterBar(
                statusFilter: _statusFilter,
                priorityFilter: _priorityFilter,
                tagFilter: _tagFilter,
                allTags: _allTags,
                onFilterTap: () => NotesFilterSheet.show(
                  context: context,
                  statusFilter: _statusFilter,
                  priorityFilter: _priorityFilter,
                  tagFilter: _tagFilter,
                  allTags: _allTags,
                  onStatusChanged: (status) =>
                      setState(() => _statusFilter = status),
                  onPriorityChanged: (priority) =>
                      setState(() => _priorityFilter = priority),
                  onTagChanged: (tagId) {
                    setState(() {
                      _tagFilter ??= {};
                      if (_tagFilter!.contains(tagId)) {
                        _tagFilter!.remove(tagId);
                        if (_tagFilter!.isEmpty) _tagFilter = null;
                      } else {
                        _tagFilter!.add(tagId);
                      }
                    });
                  },
                  onClearAll: () => setState(() {
                    _statusFilter = null;
                    _priorityFilter = null;
                    _tagFilter = null;
                  }),
                ),
                onStatusCleared: () => setState(() => _statusFilter = null),
                onPriorityCleared: () => setState(() => _priorityFilter = null),
                onTagCleared: (tagId) => setState(() {
                  _tagFilter = _tagFilter?..remove(tagId);
                  if (_tagFilter?.isEmpty ?? true) _tagFilter = null;
                }),
                onClearAll: () => setState(() {
                  _statusFilter = null;
                  _priorityFilter = null;
                  _tagFilter = null;
                }),
              ),
            // Main content
            Expanded(
              child: wideScreen
                  ? MasterDetailLayout(
                      placeholderText: l10n.selectItemToView,
                      selectedId: _selectedNoteId,
                      onSelectionChanged: (id) {
                        setState(() => _selectedNoteId = id);
                      },
                      sidebarVisible: ref.watch(sidebarVisibleProvider),
                      masterPane: _isSearching && _searchQuery.isNotEmpty
                          ? _buildSearchBody(db)
                          : _buildNotesBody(db),
                      detailPaneBuilder: (selectedId) {
                        if (selectedId == null) {
                          return const InlineDetailPlaceholder();
                        }

                        // Primary detail widget. The split-view (side-by-side
                        // compare) toggle is a desktop large-screen feature —
                        // a 50/50 horizontal split is unusable on a phone.
                        final splitToggle =
                            PlatformUtils.isDesktop && _splitViewNoteId == null
                                ? () => _showSplitNotePicker(context)
                                : null;
                        final primaryDetail = InlineNoteDetail(
                          noteId: selectedId,
                          db: db,
                          crypto: ref.read(cryptoServiceProvider),
                          onSplitViewToggle: splitToggle,
                        );

                        // If split view is active, wrap in SplitViewPane
                        if (_splitViewNoteId != null) {
                          return SplitViewPane(
                            primaryChild: primaryDetail,
                            secondaryChild: InlineNoteDetail(
                              noteId: _splitViewNoteId!,
                              db: db,
                              crypto: ref.read(cryptoServiceProvider),
                            ),
                            secondaryTitle:
                                _splitViewNoteTitle ?? l10n.untitled,
                            onClose: _closeSplitView,
                          );
                        }

                        return primaryDetail;
                      },
                    )
                  : _isSearching && _searchQuery.isNotEmpty
                      ? _buildSearchBody(db)
                      : _buildNotesBody(db),
            ),
          ],
        ),
      floatingActionButton: _isSelectionMode
          ? null
          : Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.mdOf(Theme.of(context).brightness),
              ),
              child: FloatingActionButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/notes/new');
                },
                tooltip: l10n.createNewNote,
                elevation: 0,
                highlightElevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                child: const Icon(
                  AppIcons.add,
                  size: 28,
                ),
              ),
            ),
    );
  }

  /// Build the main (non-search) notes body with infinite scroll.
  Widget _buildNotesBody(AppDatabase db) {
    if (_notes.isEmpty && _isLoadingPage) {
      // Show warm shimmer placeholders while loading the first page.
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.s8,
        ),
        itemBuilder: (_, __) => const AppLoadingCard(),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    if (_notes.isEmpty) {
      return EmptyState(
        icon: AppIcons.noteAdd,
        title: l10n.noNotesYet,
        subtitle: l10n.tapToCapture,
        actionLabel: l10n.newNote,
        onAction: () => context.push('/notes/new'),
        accentBg: AppColors.primarySoft,
        accentText: AppColors.primaryText,
      );
    }

    // Rebuild filtered notes only when filter inputs change, not on every build.
    final filterSignature =
        '${_statusFilter ?? ""}|${_priorityFilter ?? ""}|${_tagFilter?.join(",") ?? ""}';
    if (filterSignature != _lastFilterSignature) {
      _lastFilterSignature = filterSignature;
      // Fire-and-forget: _applyPropertyFilters is fast (cached) and will
      // call setState when complete.  While waiting, use the previous result.
      _applyPropertyFilters(_notes, db).then((filtered) {
        if (mounted) {
          setState(() => _filteredNotes = filtered);
        }
      });
    }

    final filtered = _filteredNotes.isEmpty && _lastFilterSignature == null
        ? _notes
        : _filteredNotes;
    final sorted = _sortNotes(filtered);

    if (filtered.isEmpty &&
        (_statusFilter != null ||
            _priorityFilter != null ||
            (_tagFilter != null && _tagFilter!.isNotEmpty))) {
      return EmptyState(
        icon: Icons.filter_list_off,
        title: l10n.noMatchingNotes,
        subtitle: l10n.tryChangingFilters,
        accentBg: AppColors.primarySoft,
        accentText: AppColors.primaryText,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final notifier = ref.read(syncStatusProvider.notifier);
        await notifier.sync();
        _resetAndReload();
      },
      child: Column(
        children: [
          // Show reorder hint when in custom sort mode.
          if (_isCustomSort && !_isGridView)
            Material(
              color: AppColors.accentPeachBg,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.accentPeachText,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      l10n.reorderModeHint,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accentPeachText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isGridView
                ? _buildNotesGrid(sorted, db, isSearchMode: false)
                : _buildNotesList(sorted, db, isSearchMode: false),
          ),
        ],
      ),
    );
  }

  /// Build search results with infinite scroll.
  Widget _buildSearchBody(AppDatabase db) {
    if (_searchResults.isEmpty && _isLoadingMoreSearch) {
      // Show warm shimmer placeholders while searching.
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.s8,
        ),
        itemBuilder: (_, __) => const AppLoadingCard(),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    if (_searchResults.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.noResults,
        subtitle: l10n.tryDifferentSearch,
        accentBg: AppColors.primarySoft,
        accentText: AppColors.primaryText,
      );
    }

    // Trigger tag and lock loading for visible search results.
    _batchLoadTagsAndLocks(_searchResults, db);

    return _isGridView
        ? _buildNotesGrid(_searchResults, db, isSearchMode: true)
        : _buildNotesList(_searchResults, db, isSearchMode: true);
  }

  Widget _buildNotesList(
    List<Note> notes,
    AppDatabase db, {
    required bool isSearchMode,
  }) {
    final showLoader =
        (isSearchMode && (_hasMoreSearchResults || _isLoadingMoreSearch)) ||
            (!isSearchMode && (_hasMore || _isLoadingPage));

    // Determine if we should animate cards on this build.
    final shouldAnimate = !isSearchMode && !_hasPlayedEntrance;
    if (shouldAnimate && notes.isNotEmpty) {
      // Mark entrance as played after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hasPlayedEntrance = true;
      });
    }

    // Use ReorderableListView in custom sort mode for drag-and-drop.
    if (_isCustomSort && !isSearchMode && !_isSelectionMode) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: notes.length,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: 96,
        ),
        onReorder: (oldIndex, newIndex) {
          _onReorder(notes, oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final note = notes[index];
          return DismissibleNoteCard(
            key: ValueKey(note.id),
            note: note,
            db: db,
            isGrid: false,
            time: _formatTime(note.updatedAt),
            tags: _cacheGet(_tagsCache, note.id) ?? [],
            isSelected: false,
            disableSwipe: true,
            onTap: () => _onNoteTap(note.id),
            onLongPress: (position) => _onNoteLongPress(note.id, position),
            onDeleted: () {},
            untitled: AppLocalizations.of(context)!.untitled,
            onStatusTap: () => _cycleStatus(note.id, db),
            onPriorityTap: () => _cyclePriority(note.id, db),
            isLocked: _cacheGet(_lockedCache, note.id) ?? false,
            listIndex: index,
            trailing: ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                child: Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: notes.length + (showLoader ? 1 : 0),
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: 96,
      ),
      itemBuilder: (context, index) {
        if (index == notes.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: _isLoadingPage || _isLoadingMoreSearch
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }
        final note = notes[index];

        // Staggered entrance: animate first N cards on initial load only.
        if (shouldAnimate && index < _kMaxAnimatedCards) {
          return StaggeredCardEntrance(
            index: index,
            staggerDelay: _kStaggerDelayMs,
            child: _buildDismissibleNoteCard(note, db, isGrid: false, listIndex: index),
          );
        }

        return _buildDismissibleNoteCard(note, db, isGrid: false, listIndex: index);
      },
    );
  }

  Widget _buildNotesGrid(
    List<Note> notes,
    AppDatabase db, {
    required bool isSearchMode,
  }) {
    final showLoader =
        (isSearchMode && (_hasMoreSearchResults || _isLoadingMoreSearch)) ||
            (!isSearchMode && (_hasMore || _isLoadingPage));

    // Determine if we should animate cards on this build.
    final shouldAnimate = !isSearchMode && !_hasPlayedEntrance;
    if (shouldAnimate && notes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hasPlayedEntrance = true;
      });
    }

    final items = <Widget>[];
    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final card =
          _buildDismissibleNoteCard(note, db, isGrid: true, listIndex: i);

      if (shouldAnimate && i < _kMaxAnimatedCards) {
        items.add(
          StaggeredCardEntrance(
            index: i,
            staggerDelay: _kStaggerDelayMs,
            child: card,
          ),
        );
      } else {
        items.add(card);
      }
    }

    // Loading indicator at the bottom
    if (showLoader) {
      items.add(
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: _isLoadingPage || _isLoadingMoreSearch
                ? const CircularProgressIndicator()
                : const SizedBox.shrink(),
          ),
        ),
      );
    }

    return MasonryGridView.builder(
      controller: _scrollController,
      gridDelegate: SliverSimpleGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth(context),
      ),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.s8,
      ).copyWith(bottom: 96),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// Build a note card wrapped in a Dismissible for swipe actions.
  ///
  /// Delegates to the extracted [DismissibleNoteCard] widget.
  Widget _buildDismissibleNoteCard(
    Note note,
    AppDatabase db, {
    required bool isGrid,
    int listIndex = 0,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final time = _formatTime(note.updatedAt);
    final tags = _cacheGet(_tagsCache, note.id) ?? [];
    final isLocked = _cacheGet(_lockedCache, note.id) ?? false;
    final properties = _cacheGet(_propertiesCache, note.id);
    final isSelected = _isSelectionMode
        ? _selectedNoteIds.contains(note.id)
        : _selectedNoteId == note.id;

    return DismissibleNoteCard(
      note: note,
      db: db,
      isGrid: isGrid,
      time: time,
      tags: tags,
      isSelected: isSelected,
      disableSwipe: _isSelectionMode,
      onTap: () => _onNoteTap(note.id),
      onLongPress: (position) => _onNoteLongPress(note.id, position),
      onDeleted: () {},
      untitled: l10n.untitled,
      onStatusTap: () => _cycleStatus(note.id, db),
      onPriorityTap: () => _cyclePriority(note.id, db),
      isLocked: isLocked,
      properties: properties,
      listIndex: listIndex,
    );
  }

  /// Cycle through status options for a note.
  Future<void> _cycleStatus(String noteId, AppDatabase db) async {
    const statuses = ['Todo', 'In Progress', 'Done', 'Blocked', 'Cancelled'];
    final current = await db.notePropertiesDao.getProperty(
      noteId,
      BuiltInProperties.status,
    );
    final currentIndex =
        current != null ? statuses.indexOf(current.valueText ?? '') : -1;
    final nextIndex = (currentIndex + 1) % statuses.length;
    final nextStatus = statuses[nextIndex];

    if (current != null) {
      await db.notePropertiesDao.updateTextProperty(
        id: current.id,
        value: nextStatus,
      );
    } else {
      await db.notePropertiesDao.createTextProperty(
        id: const Uuid().v4(),
        noteId: noteId,
        key: BuiltInProperties.status,
        value: nextStatus,
      );
    }
    // Invalidate properties cache
    _propertiesCache.remove(noteId);
    setState(() {});
  }

  /// Cycle through priority options for a note.
  Future<void> _cyclePriority(String noteId, AppDatabase db) async {
    const priorities = ['High', 'Medium', 'Low'];
    final current = await db.notePropertiesDao.getProperty(
      noteId,
      BuiltInProperties.priority,
    );
    final currentIndex =
        current != null ? priorities.indexOf(current.valueText ?? '') : -1;
    final nextIndex = (currentIndex + 1) % priorities.length;
    final nextPriority = priorities[nextIndex];

    if (current != null) {
      await db.notePropertiesDao.updateTextProperty(
        id: current.id,
        value: nextPriority,
      );
    } else {
      await db.notePropertiesDao.createTextProperty(
        id: const Uuid().v4(),
        noteId: noteId,
        key: BuiltInProperties.priority,
        value: nextPriority,
      );
    }
    // Invalidate properties cache
    _propertiesCache.remove(noteId);
    setState(() {});
  }

  /// Handle note tap: select in selection mode, otherwise navigate.
  void _onNoteTap(String noteId) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedNoteIds.contains(noteId)) {
          _selectedNoteIds.remove(noteId);
        } else {
          _selectedNoteIds.add(noteId);
        }
        // Exit selection mode if nothing is selected
        if (_selectedNoteIds.isEmpty) {
          _isSelectionMode = false;
        }
      });
    } else if (_isWideScreen) {
      setState(() {
        _selectedNoteId = noteId;
        // Close split view when switching primary notes.
        _splitViewNoteId = null;
        _splitViewNoteTitle = null;
      });
    } else {
      final target = '/notes/$noteId';
      if (!NavGuard.canNavigate(target)) return;
      context.push(target);
    }
  }

  /// Handle note long press: show context menu at the press position
  /// and enter selection mode.
  void _onNoteLongPress(String noteId, Offset position) {
    if (!_isSelectionMode) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isSelectionMode = true;
        _selectedNoteIds.add(noteId);
      });
    }

    // Compute the menu position from the long press coordinates.
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final menuPosition = RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    );

    // Show a context menu with lock/unlock and move options.
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    showMenu<String>(
      context: context,
      position: menuPosition,
      items: [
        PopupMenuItem(
          value: 'lock',
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.lockNote),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'unlock',
          child: ListTile(
            leading: const Icon(Icons.lock_open),
            title: Text(l10n.unlockNote),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'move',
          child: ListTile(
            leading: const Icon(Icons.create_new_folder_outlined),
            title: Text(l10n.addToCollection),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'lock' || value == 'unlock') {
        _toggleNoteLock(noteId, db, l10n);
      } else if (value == 'move') {
        _moveToCollection(db, l10n, [noteId]);
      }
    });
  }

  /// Show a bottom sheet with import options (Markdown, Text, Apple Notes).
  void _showImportSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: AppSpacing.s8,
                  bottom: AppSpacing.s4,
                ),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s12,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.importNotes,
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.importMarkdown),
              onTap: () {
                Navigator.pop(ctx);
                _performImport(context, ImportType.markdown);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: Text(l10n.importTextFiles),
              onTap: () {
                Navigator.pop(ctx);
                _performImport(context, ImportType.text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: Text(l10n.importAppleNotes),
              onTap: () {
                Navigator.pop(ctx);
                _performImport(context, ImportType.appleNotes);
              },
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }

  /// Which type of import the user selected.
  void _performImport(BuildContext context, ImportType type) async {
    final l10n = AppLocalizations.of(context)!;

    // File system APIs are not available on web platform.
    if (kIsWeb) {
      AppSnackBar.error(
        context,
        message: AppLocalizations.of(context)?.notAvailableOnWeb ??
            'This feature is not available on web',
      );
      return;
    }

    // Show a progress dialog.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppSpacing.s20),
            Flexible(child: Text(l10n.importNotes)),
          ],
        ),
      ),
    );

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final mdImporter = MarkdownImportService(
        cryptoService: crypto,
        database: db,
      );

      ImportResult result;

      switch (type) {
        case ImportType.markdown:
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: l10n.importMarkdown,
          );
          if (dirPath == null) {
            if (context.mounted) Navigator.pop(context);
            return;
          }
          result = await mdImporter.importFromDirectory(Directory(dirPath));

        case ImportType.text:
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: l10n.importTextFiles,
          );
          if (dirPath == null) {
            if (context.mounted) Navigator.pop(context);
            return;
          }
          final txtImporter = TextImporter();
          final notes = await txtImporter.parseTextDirectory(
            Directory(dirPath),
          );
          // Drain the import stream to persist notes.
          await mdImporter.importNotes(notes).drain<void>();
          result = ImportResult(
            importedCount: notes.length,
            skippedCount: 0,
          );

        case ImportType.appleNotes:
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: l10n.importAppleNotes,
          );
          if (dirPath == null) {
            if (context.mounted) Navigator.pop(context);
            return;
          }
          final appleImporter = AppleNotesImporter();
          final notes = await appleImporter.parseHtmlDirectory(
            Directory(dirPath),
          );
          // Drain the import stream to persist notes.
          await mdImporter.importNotes(notes).drain<void>();
          result = ImportResult(
            importedCount: notes.length,
            skippedCount: 0,
          );
      }

      if (!context.mounted) return;

      // Close progress dialog.
      Navigator.pop(context);

      // Show result snackbar.
      AppSnackBar.info(
        context,
        message: l10n.importComplete(result.importedCount, result.skippedCount),
      );

      // Reload notes list.
      _resetAndReload();
    } catch (e) {
      if (!context.mounted) return;
      // Close progress dialog.
      Navigator.pop(context);
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(
        context,
        message: l10n
            .importFailed(ErrorDisplay.displayMessage(e, l10n)),
      );
    }
  }

  /// Show a bottom sheet with "Blank Note" and "From Template" options.
  void _showCreateOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: AppSpacing.s8,
                  bottom: AppSpacing.s4,
                ),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            ListTile(
              leading: const Icon(AppIcons.noteAdd),
              title: Text(l10n.blankNote),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/notes/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.fromTemplate),
              onTap: () {
                Navigator.pop(ctx);
                _openTemplatePicker(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.dailyNote),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/notes/daily');
              },
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }

  /// Open the template picker bottom sheet.
  void _openTemplatePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (_) => TemplatePickerSheet(
        onSelected: (content) {
          // Navigate to the note editor with the template content.
          // We pass the content via the query parameter.
          context.push(
            '/notes/new?templateContent=${Uri.encodeComponent(content)}',
          );
        },
      ),
    );
  }

  /// Show the note picker sheet for selecting a note to open in split view.
  void _showSplitNotePicker(BuildContext context) {
    final excludeIds = <String>{};
    if (_selectedNoteId != null) excludeIds.add(_selectedNoteId!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (_) => SplitNotePickerSheet(
        excludeIds: excludeIds,
        onSelect: (noteId, title) {
          setState(() {
            _splitViewNoteId = noteId;
            _splitViewNoteTitle = title;
          });
        },
      ),
    );
  }

  /// Close the split view and clear the secondary note.
  void _closeSplitView() {
    setState(() {
      _splitViewNoteId = null;
      _splitViewNoteTitle = null;
    });
  }

  /// Select all notes in the current list.
  void _selectAllNotes() {
    setState(() {
      _selectedNoteIds = _notes.map((n) => n.id).toSet();
    });
  }

  /// Deselect all notes.
  void _deselectAllNotes() {
    setState(() {
      _selectedNoteIds.clear();
    });
  }

  /// Exit search mode and restore the normal note list.
  void _exitSearchMode() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults.clear();
    });
    _loadInitialNotes();
  }

  /// Exit selection mode.
  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  /// Toggle pin status for all selected notes.
  Future<void> _batchTogglePin(AppDatabase db, AppLocalizations l10n) async {
    if (_selectedNoteIds.isEmpty) return;

    // Determine if we should pin or unpin based on the majority
    final hasPinned = _selectedNoteIds.any((id) {
      final note = _notes.firstWhereOrNull((n) => n.id == id);
      return note?.isPinned ?? false;
    });

    await db.notesDao.bulkPin(_selectedNoteIds.toList(), !hasPinned);
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    AppSnackBar.info(
      context,
      message: hasPinned
          ? l10n.notesUnpinned(_selectedNoteIds.length)
          : l10n.notesPinned(_selectedNoteIds.length),
    );

    _exitSelectionMode();
  }

  /// Delete all selected notes (move to trash).
  Future<void> _batchDelete(AppDatabase db, AppLocalizations l10n) async {
    if (_selectedNoteIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSelectedNotes(_selectedNoteIds.length)),
        content: Text(l10n.deleteSelectedNotesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await db.notesDao.bulkSoftDelete(_selectedNoteIds.toList());

      if (!mounted) return;

      AppSnackBar.info(
        context,
        message: l10n.notesDeleted(_selectedNoteIds.length),
        actionLabel: l10n.undo,
        onAction: () async {
          await db.notesDao.bulkRestore(_selectedNoteIds.toList());
          _resetAndReload();
        },
      );

      _exitSelectionMode();
      _resetAndReload();
    }
  }

  /// Add tags to all selected notes.
  Future<void> _batchAddTags(AppDatabase db, AppLocalizations l10n) async {
    if (_selectedNoteIds.isEmpty) return;

    // Show tag picker
    final allTags = await db.tagsDao.getAllTags();

    if (!mounted) return;

    final selectedTags = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => TagPickerDialog(
        existingTags: allTags,
      ),
    );

    if (selectedTags != null && selectedTags.isNotEmpty) {
      for (final noteId in _selectedNoteIds) {
        for (final tagId in selectedTags) {
          await db.notesDao.addTagToNote(noteId, tagId);
        }
      }

      if (!mounted) return;

      // Refresh tag cache for affected notes
      for (final noteId in _selectedNoteIds) {
        _tagsCache.remove(noteId);
      }

      AppSnackBar.info(context, message: l10n.tags);

      _exitSelectionMode();
    }
  }

  /// Show the export bottom sheet for selected notes.
  void _showExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExportSheet(
        selectedNoteIds: _selectedNoteIds,
        scope: ExportScope.selectedNotes,
      ),
    );
  }

  /// Compare the two currently selected notes by navigating to the diff screen.
  void _compareSelectedNotes() {
    if (_selectedNoteIds.length != 2) return;
    final ids = _selectedNoteIds.toList();
    _exitSelectionMode();
    context.push('/notes/compare?left=${ids[0]}&right=${ids[1]}');
  }

  /// Show color picker and apply selected color to all selected notes.
  Future<void> _batchColor(AppDatabase db, AppLocalizations l10n) async {
    if (_selectedNoteIds.isEmpty) return;

    final selectedColor = await showColorPickerSheet(context);
    if (selectedColor == null) return; // User dismissed the sheet.

    final ids = _selectedNoteIds.toList();
    if (selectedColor.isEmpty) {
      // Empty string means "remove color".
      for (final id in ids) {
        await db.notesDao.updateNoteColor(id, null);
      }
    } else {
      for (final id in ids) {
        await db.notesDao.updateNoteColor(id, selectedColor);
      }
    }

    if (!mounted) return;

    AppSnackBar.info(
      context,
      message: selectedColor.isEmpty
          ? l10n.colorRemovedFromNotes(ids.length)
          : l10n.notesColored(ids.length),
    );

    _exitSelectionMode();
  }

  /// Batch lock all selected notes. Shows a confirmation and locks them.
  Future<void> _batchLock(AppDatabase db, AppLocalizations l10n) async {
    if (_selectedNoteIds.isEmpty) return;

    // Check if any are already locked to determine action (lock vs unlock).
    final propsDao = db.notePropertiesDao;
    final ids = _selectedNoteIds.toList();
    bool anyLocked = false;
    for (final id in ids) {
      if (await propsDao.isNoteLocked(id)) {
        anyLocked = true;
        break;
      }
    }

    final shouldLock = !anyLocked;
    await propsDao.bulkSetLocked(ids, shouldLock);

    if (!mounted) return;

    AppSnackBar.info(
      context,
      message: shouldLock
          ? l10n.notesLocked(ids.length)
          : l10n.notesUnlocked(ids.length),
    );

    _exitSelectionMode();
  }

  /// Toggle lock state for a single note (called from long-press menu).
  Future<void> _toggleNoteLock(
    String noteId,
    AppDatabase db,
    AppLocalizations l10n,
  ) async {
    final propsDao = db.notePropertiesDao;
    final isLocked = await propsDao.isNoteLocked(noteId);
    await propsDao.setNoteLocked(noteId, !isLocked);

    // Invalidate the cache for this note so the lock icon updates.
    _lockedCache.remove(noteId);
    _loadLockForNote(noteId, db);

    if (!mounted) return;

    AppSnackBar.info(
      context,
      message: isLocked ? l10n.unlockNote : l10n.lockNote,
    );
  }

  /// Move notes to a collection via the collection picker sheet.
  Future<void> _moveToCollection(
    AppDatabase db,
    AppLocalizations l10n,
    List<String> noteIds,
  ) async {
    final collection = await showCollectionPickerSheet(
      context,
      noteIds: noteIds,
    );
    if (collection == null || !mounted) return;

    for (final noteId in noteIds) {
      await db.collectionsDao.addNoteToCollection(
        collectionId: collection.id,
        noteId: noteId,
      );
    }

    if (!mounted) return;

    final message = noteIds.length == 1
        ? l10n.noteMovedToCollection(
            collection.plainTitle ?? l10n.untitledCollection,
          )
        : l10n.notesMovedToCollection(
            noteIds.length,
            collection.plainTitle ?? l10n.untitledCollection,
          );

    AppSnackBar.info(context, message: message);

    if (_isSelectionMode) _exitSelectionMode();
  }

  String _formatTime(DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return DateFormat.MMMd().format(dt);
  }

  /// Build a sort-option menu item with a check indicator for the active sort.
  PopupMenuItem<String> _buildSortMenuItem(
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = _sortOption == value;
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuItem<String>(
      value: value,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? primary : null),
        title: Text(label),
        trailing: isSelected ? const Icon(Icons.check, size: 18) : null,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
