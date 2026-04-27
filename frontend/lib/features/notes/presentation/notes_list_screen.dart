import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/note_properties_dao.dart';
import '../../../core/import/apple_notes_import.dart';
import '../../../core/import/import_models.dart';
import '../../../core/import/markdown_import_service.dart';
import '../../../core/import/text_import.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../../core/widgets/color_picker_sheet.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/master_detail_layout.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/sidebar_provider.dart';
import '../../../core/widgets/pressable_scale.dart';
import 'widgets/sync_status_indicator.dart';
import '../../../l10n/app_localizations.dart';
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

  bool _isGridView = false;
  String _sortOption = 'updated_newest';

  /// Whether the current sort mode is custom (drag-and-drop reorder).
  bool get _isCustomSort => _sortOption == 'custom';

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

  /// Whether the scroll-to-top FAB should be visible.
  bool _showScrollToTop = false;

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.autoLoad) {
      _loadInitialNotes();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Property filtering
  // ---------------------------------------------------------------------------

  /// Apply property filters to the notes list.
  Future<List<Note>> _applyPropertyFilters(
    List<Note> notes,
    AppDatabase db,
  ) async {
    if (_statusFilter == null && _priorityFilter == null) {
      return notes;
    }

    final filtered = <Note>[];

    for (final note in notes) {
      // Load properties for this note (use cache if available)
      List<NoteProperty>? properties = _propertiesCache[note.id];
      if (properties == null) {
        properties = await db.notePropertiesDao.getPropertiesForNote(note.id);
        if (_propertiesCache.length >= _maxPropertiesCacheSize) {
          _propertiesCache.remove(_propertiesCache.keys.first);
        }
        _propertiesCache[note.id] = properties;
      }

      bool matchesStatus = true;
      bool matchesPriority = true;

      for (final property in properties) {
        if (property.key == BuiltInProperties.status &&
            property.valueText == _statusFilter) {
          matchesStatus = true;
        }
        if (property.key == BuiltInProperties.priority &&
            property.valueText == _priorityFilter) {
          matchesPriority = true;
        }
      }

      // If filter is set and property doesn't match, exclude
      if (_statusFilter != null) {
        final hasStatus = properties.any(
          (p) =>
              p.key == BuiltInProperties.status && p.valueText == _statusFilter,
        );
        matchesStatus = hasStatus;
      }

      if (_priorityFilter != null) {
        final hasPriority = properties.any(
          (p) =>
              p.key == BuiltInProperties.priority &&
              p.valueText == _priorityFilter,
        );
        matchesPriority = hasPriority;
      }

      if (matchesStatus && matchesPriority) {
        filtered.add(note);
      }
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
        });

        for (final note in firstPage) {
          _loadTagsForNote(note.id, db);
          _loadLockForNote(note.id, db);
        }
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

    for (final note in uniqueNewNotes) {
      _loadTagsForNote(note.id, db);
      _loadLockForNote(note.id, db);
    }
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
        for (final note in results) {
          _loadTagsForNote(note.id, db);
          _loadLockForNote(note.id, db);
        }
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

    for (final note in uniqueNew) {
      _loadTagsForNote(note.id, db);
      _loadLockForNote(note.id, db);
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll detection
  // ---------------------------------------------------------------------------

  /// Scroll listener: load more when user is near the bottom (80%).
  /// Also toggles the scroll-to-top FAB based on scroll offset.
  void _onScroll() {
    // Update scroll-to-top visibility.
    final currentOffset = _scrollController.position.pixels;
    final shouldShow = currentOffset > 1000;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }

    if (_isLoadingPage && _isLoadingMoreSearch) return;

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

  /// Load tags for a single note and cache them.
  Future<void> _loadTagsForNote(String noteId, AppDatabase db) async {
    if (_tagsCache.containsKey(noteId)) return;
    final tags = await db.tagsDao.getTagsForNote(noteId);
    if (mounted) {
      setState(() {
        _tagsCache[noteId] = tags;
        // Evict oldest entries when the cache exceeds the max size.
        while (_tagsCache.length > _maxTagsCacheSize) {
          _tagsCache.remove(_tagsCache.keys.first);
        }
      });
    }
  }

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
        sorted.sort((a, b) {
          final ta = a.plainTitle ?? untitled;
          final tb = b.plainTitle ?? untitled;
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final db = ref.read(databaseProvider);
    final wideScreen = AdaptiveScaffold.isDesktop(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
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
                ),
              )
            : _isSelectionMode
                ? Text(l10n.selectedNotes(_selectedNoteIds.length))
                : Text(l10n.appTitle),
        actions: [
          if (_isSelectionMode) ...[
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
              icon: const Icon(Icons.close),
              tooltip: l10n.done,
              onPressed: _exitSelectionMode,
            ),
          ] else ...[
            // Sync status indicator (green/yellow/red dot + label)
            const SyncStatusIndicator(),
            // Trash icon with badge count
            StreamBuilder<int>(
              stream: db.notesDao.watchDeletedNotesCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.trash,
                      onPressed: () => context.push('/trash'),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Import
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: l10n.importNotes,
              onPressed: () => _showImportSheet(context),
            ),
            // Collections
            IconButton(
              icon: const Icon(Icons.folder_outlined),
              tooltip: l10n.collections,
              onPressed: () => context.push('/collections'),
            ),
            // Knowledge Graph
            IconButton(
              icon: const Icon(Icons.account_tree_outlined),
              tooltip: l10n.knowledgeGraph,
              onPressed: () => context.push('/notes/graph'),
            ),
            // Properties Dashboard
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: l10n.propertiesDashboard,
              onPressed: () => context.push('/notes/dashboard'),
            ),
            // Statistics
            IconButton(
              icon: const Icon(Icons.bar_chart_outlined),
              tooltip: l10n.statistics,
              onPressed: () => context.push('/notes/statistics'),
            ),
            // Daily Notes (Calendar)
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: l10n.dailyNotes,
              onPressed: () => context.push('/notes/daily'),
            ),
            // Reminders
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: l10n.reminders,
              onPressed: () => context.push('/notes/reminders'),
            ),
            // Orphaned Notes
            IconButton(
              icon: const Icon(Icons.scatter_plot_outlined),
              tooltip: l10n.orphanedNotes,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => const OrphanedNotesSheet(),
                );
              },
            ),
            // Code Snippets
            IconButton(
              icon: const Icon(Icons.code_outlined),
              tooltip: l10n.snippets,
              onPressed: () => context.push('/snippets'),
            ),
            // Sort menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: l10n.sortNotes,
              onSelected: (value) {
                setState(() => _sortOption = value);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'updated_newest',
                  child: Text(l10n.updatedNewest),
                ),
                PopupMenuItem(
                  value: 'updated_oldest',
                  child: Text(l10n.updatedOldest),
                ),
                PopupMenuItem(
                  value: 'created_newest',
                  child: Text(l10n.createdNewest),
                ),
                PopupMenuItem(
                  value: 'created_oldest',
                  child: Text(l10n.createdOldest),
                ),
                PopupMenuItem(
                  value: 'title_az',
                  child: Text(l10n.titleAZ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'custom',
                  child: Text(l10n.sortCustom),
                ),
              ],
            ),
            // Grid/List toggle
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              tooltip: _isGridView ? l10n.listView : l10n.gridView,
              onPressed: () {
                setState(() => _isGridView = !_isGridView);
              },
            ),
            // Advanced search (visible when searching)
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: l10n.advancedSearch,
                onPressed: () => context.push('/search'),
              ),
            // Command palette trigger
            if (!_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.keyboard_command_key),
                tooltip: l10n.commandPalette,
                onPressed: showCommandPalette,
              ),
            // Search toggle
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              tooltip:
                  _isSearching ? l10n.closeSearch : l10n.searchNotesTooltip,
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                    _searchResults.clear();
                    _hasMoreSearchResults = true;
                    // Restart the reactive first-page subscription.
                    _loadInitialNotes();
                  } else {
                    // Entering search mode: cancel the normal page subscription.
                    _pageSubscription?.cancel();
                  }
                });
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Offline banner at the top
          const OfflineBanner(),
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
          // Property filter bar
          if (!_isSearching)
            NotesFilterBar(
              statusFilter: _statusFilter,
              priorityFilter: _priorityFilter,
              onFilterTap: () => NotesFilterSheet.show(
                context: context,
                statusFilter: _statusFilter,
                priorityFilter: _priorityFilter,
                onStatusChanged: (status) =>
                    setState(() => _statusFilter = status),
                onPriorityChanged: (priority) =>
                    setState(() => _priorityFilter = priority),
              ),
              onStatusCleared: () => setState(() => _statusFilter = null),
              onPriorityCleared: () => setState(() => _priorityFilter = null),
              onClearAll: () => setState(() {
                _statusFilter = null;
                _priorityFilter = null;
              }),
            ),
          // Main content
          Expanded(
            child: wideScreen
                ? MasterDetailLayout(
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

                      // Primary detail widget
                      final primaryDetail = InlineNoteDetail(
                        noteId: selectedId,
                        db: db,
                        crypto: ref.read(cryptoServiceProvider),
                        onSplitViewToggle: _splitViewNoteId == null
                            ? () => _showSplitNotePicker(context)
                            : null,
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
                          secondaryTitle: _splitViewNoteTitle ?? l10n.untitled,
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
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Scroll-to-top FAB with fade animation.
                AnimatedOpacity(
                  opacity: _showScrollToTop ? 1.0 : 0.0,
                  duration: AppDurations.mediumAnimation,
                  child: AnimatedSlide(
                    offset:
                        _showScrollToTop ? Offset.zero : const Offset(0, 0.5),
                    duration: AppDurations.mediumAnimation,
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showScrollToTop,
                      child: Semantics(
                        button: true,
                        label: l10n.scrollToTop,
                        child: FloatingActionButton.small(
                          onPressed: () {
                            _scrollController.animateTo(
                              0,
                              duration: AppDurations.longAnimation,
                              curve: Curves.easeOutCubic,
                            );
                          },
                          tooltip: l10n.scrollToTop,
                          child: const Icon(Icons.arrow_upward),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Create new note FAB.
                PressableScale(
                  onPressed: () => _showCreateOptions(context),
                  child: Semantics(
                    button: true,
                    label: l10n.createNewNote,
                    child: FloatingActionButton(
                      onPressed: () => _showCreateOptions(context),
                      tooltip: l10n.createNewNote,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Build the main (non-search) notes body with infinite scroll.
  Widget _buildNotesBody(AppDatabase db) {
    if (_notes.isEmpty && _isLoadingPage) {
      // Show warm shimmer placeholders while loading the first page.
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemBuilder: (_, __) => const AppLoadingCard(),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    if (_notes.isEmpty) {
      return EmptyState(
        icon: Icons.note_add_outlined,
        title: l10n.noNotesYet,
        subtitle: l10n.tapToCapture,
        actionLabel: l10n.newNote,
        onAction: () => context.push('/notes/new'),
      );
    }

    // Use FutureBuilder for async property filtering
    return FutureBuilder<List<Note>>(
      future: _applyPropertyFilters(_notes, db),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
                _statusFilter != null ||
            _priorityFilter != null) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snapshot.data ?? _notes;
        final sorted = _sortNotes(filtered);

        if (filtered.isEmpty &&
            (_statusFilter != null || _priorityFilter != null)) {
          return EmptyState(
            icon: Icons.filter_list_off,
            title: l10n.noMatchingNotes,
            subtitle: l10n.tryChangingFilters,
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
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.reorderModeHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
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
      },
    );
  }

  /// Build search results with infinite scroll.
  Widget _buildSearchBody(AppDatabase db) {
    if (_searchResults.isEmpty && _isLoadingMoreSearch) {
      // Show warm shimmer placeholders while searching.
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemBuilder: (_, __) => const AppLoadingCard(),
      );
    }

    final l10n = AppLocalizations.of(context)!;

    if (_searchResults.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.noResults,
        subtitle: l10n.tryDifferentSearch,
      );
    }

    // Trigger tag and lock loading for visible search results.
    for (final note in _searchResults) {
      _loadTagsForNote(note.id, db);
      _loadLockForNote(note.id, db);
    }

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
        padding: const EdgeInsets.only(bottom: 80),
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
            tags: _tagsCache[note.id] ?? [],
            isSelected: false,
            disableSwipe: true,
            onTap: () => _onNoteTap(note.id),
            onLongPress: () => _onNoteLongPress(note.id),
            onDeleted: () {},
            untitled: AppLocalizations.of(context)!.untitled,
            onStatusTap: () => _cycleStatus(note.id, db),
            onPriorityTap: () => _cyclePriority(note.id, db),
            isLocked: _lockedCache[note.id] ?? false,
            trailing: ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        if (index == notes.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
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
            child: _buildDismissibleNoteCard(note, db, isGrid: false),
          );
        }

        return _buildDismissibleNoteCard(note, db, isGrid: false);
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

    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
      ),
      itemCount: notes.length + (showLoader ? 1 : 0),
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        if (index == notes.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoadingPage || _isLoadingMoreSearch
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }
        final note = notes[index];

        // Staggered entrance for grid view too.
        if (shouldAnimate && index < _kMaxAnimatedCards) {
          return StaggeredCardEntrance(
            index: index,
            staggerDelay: _kStaggerDelayMs,
            child: _buildDismissibleNoteCard(note, db, isGrid: true),
          );
        }

        return _buildDismissibleNoteCard(note, db, isGrid: true);
      },
    );
  }

  /// Build a note card wrapped in a Dismissible for swipe actions.
  ///
  /// Delegates to the extracted [DismissibleNoteCard] widget.
  Widget _buildDismissibleNoteCard(
    Note note,
    AppDatabase db, {
    required bool isGrid,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final time = _formatTime(note.updatedAt);
    final tags = _tagsCache[note.id] ?? [];
    final isLocked = _lockedCache[note.id] ?? false;
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
      onLongPress: () => _onNoteLongPress(note.id),
      onDeleted: () {},
      untitled: l10n.untitled,
      onStatusTap: () => _cycleStatus(note.id, db),
      onPriorityTap: () => _cyclePriority(note.id, db),
      isLocked: isLocked,
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
      context.push('/notes/$noteId');
    }
  }

  /// Handle note long press: show context menu and enter selection mode.
  void _onNoteLongPress(String noteId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedNoteIds.add(noteId);
      });
    }

    // Show a context menu with lock/unlock and move options.
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);
    showMenu<String>(
      context: context,
      position: RelativeRect.fill,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.importNotes,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
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
            const SizedBox(height: 8),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.notAvailableOnWeb ??
                'This feature is not available on web',
          ),
        ),
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
            const SizedBox(width: 20),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.importComplete(result.importedCount, result.skippedCount),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // Reload notes list.
      _resetAndReload();
    } catch (e) {
      if (!context.mounted) return;
      // Close progress dialog.
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.importFailed(e.toString())),
        ),
      );
    }
  }

  /// Show a bottom sheet with "Blank Note" and "From Template" options.
  void _showCreateOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
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
            const SizedBox(height: 8),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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

  /// Exit selection mode.
  void _exitSelectionMode() {
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

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasPinned
              ? l10n.notesUnpinned(_selectedNoteIds.length)
              : l10n.notesPinned(_selectedNoteIds.length),
        ),
      ),
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
      await db.notesDao.bulkSoftDelete(_selectedNoteIds.toList());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.notesDeleted(_selectedNoteIds.length)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await db.notesDao.bulkRestore(_selectedNoteIds.toList());
              _resetAndReload();
            },
          ),
        ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tags),
        ),
      );

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedColor.isEmpty
              ? l10n.colorRemovedFromNotes(ids.length)
              : l10n.notesColored(ids.length),
        ),
      ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shouldLock
              ? l10n.notesLocked(ids.length)
              : l10n.notesUnlocked(ids.length),
        ),
      ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isLocked ? l10n.unlockNote : l10n.lockNote,
        ),
      ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

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
    return '${dt.month}/${dt.day}';
  }
}
