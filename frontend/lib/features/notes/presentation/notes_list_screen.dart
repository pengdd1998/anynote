import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_utils.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/import/apple_notes_import.dart';
import '../../../core/import/import_models.dart';
import '../../../core/import/markdown_import_service.dart';
import '../../../core/import/text_import.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/master_detail_layout.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/sidebar_provider.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../settings/data/settings_providers.dart';
import 'template_picker.dart';

/// Page size for paginated note loading.
/// 50 items balances smooth scrolling with low memory usage.
/// At ~200 bytes per Note object in memory, 50 notes = ~10 KB.
const _kPageSize = 50;

/// Which import source the user picked from the import bottom sheet.
enum ImportType { markdown, text, appleNotes }

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialNotes();
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
    }
  }

  /// Reset pagination state and reload from scratch.
  /// Re-triggers the staggered entrance animation.
  void _resetAndReload() {
    _pageSubscription?.cancel();
    _tagsCache.clear();
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

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll detection
  // ---------------------------------------------------------------------------

  /// Scroll listener: load more when user is near the bottom (80%).
  void _onScroll() {
    if (_isLoadingPage && _isLoadingMoreSearch) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final nearBottom = currentScroll >= maxScroll * 0.8;

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
    }

    // Always move pinned notes to the top.
    sorted.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });

    return sorted;
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
            : Text(l10n.appTitle),
        actions: [
          // Sync status with pending count badge
          const SyncStatusWidget(),
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
          // Search toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? l10n.closeSearch : l10n.searchNotesTooltip,
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
      ),
      body: Column(
        children: [
          // Offline banner at the top
          const OfflineBanner(),
          // Main content
          Expanded(
            child: wideScreen
                ? MasterDetailLayout(
                    selectedId: _selectedNoteId,
                    onSelectionChanged: (id) {
                      setState(() => _selectedNoteId = id);
                    },
                    sidebarVisible:
                        ref.watch(sidebarVisibleProvider),
                    masterPane: _isSearching && _searchQuery.isNotEmpty
                        ? _buildSearchBody(db)
                        : _buildNotesBody(db),
                    detailPaneBuilder: (selectedId) {
                      if (selectedId == null) {
                        return const _InlineDetailPlaceholder();
                      }
                      return _InlineNoteDetail(
                        noteId: selectedId,
                        db: db,
                        crypto: ref.read(cryptoServiceProvider),
                      );
                    },
                  )
                : _isSearching && _searchQuery.isNotEmpty
                    ? _buildSearchBody(db)
                    : _buildNotesBody(db),
          ),
        ],
      ),
      floatingActionButton: PressableScale(
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

    final sorted = _sortNotes(_notes);

    return RefreshIndicator(
      onRefresh: () async {
        final notifier = ref.read(syncStatusProvider.notifier);
        await notifier.sync();
        _resetAndReload();
      },
      child: _isGridView
          ? _buildNotesGrid(sorted, db, isSearchMode: false)
          : _buildNotesList(sorted, db, isSearchMode: false),
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

    // Trigger tag loading for visible search results.
    for (final note in _searchResults) {
      _loadTagsForNote(note.id, db);
    }

    return _isGridView
        ? _buildNotesGrid(_searchResults, db, isSearchMode: true)
        : _buildNotesList(_searchResults, db, isSearchMode: true);
  }

  Widget _buildNotesList(
      List<Note> notes, AppDatabase db, {required bool isSearchMode,}) {
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
          return _StaggeredCardEntrance(
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
      List<Note> notes, AppDatabase db, {required bool isSearchMode,}) {
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
          return _StaggeredCardEntrance(
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
  /// Swipe right (start-to-end) toggles pin with warm primary background.
  /// Swipe left (end-to-start) deletes with warm error background.
  /// Both backgrounds have rounded corners matching the card shape.
  Widget _buildDismissibleNoteCard(
    Note note,
    AppDatabase db, {
    required bool isGrid,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final cardRadius = BorderRadius.circular(AppTheme.radiusMedium);

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.4,
      },
      // Right swipe: pin/unpin with warm primary color.
      background: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary.withAlpha(40),
          borderRadius: cardRadius,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Semantics(
          label: note.isPinned ? l10n.unpinNote : l10n.pinNote,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 2),
              Text(
                note.isPinned ? l10n.unpinNote : l10n.pinNote,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      // Left swipe: delete with warm error color.
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: colorScheme.error.withAlpha(40),
          borderRadius: cardRadius,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Semantics(
          label: l10n.deleteNote,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: colorScheme.error),
              const SizedBox(height: 2),
              Text(
                l10n.deleteNote,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Pin/unpin does not dismiss; just toggle and return false.
          await db.notesDao.togglePin(note.id);
          return false;
        }
        // Delete: confirm via dialog.
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteNoteQuestion),
            content: Text(
              l10n.deleteNoteConfirm(note.plainTitle ?? l10n.untitled),
            ),
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
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          db.notesDao.softDeleteNote(note.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noteDeleted),
              action: SnackBarAction(
                label: l10n.undo,
                onPressed: () async {
                  await (db.update(db.notes)
                        ..where((n) => n.id.equals(note.id)))
                      .write(const NotesCompanion(
                    deletedAt: Value(null),
                    isSynced: Value(false),
                  ),);
                },
              ),
            ),
          );
        }
      },
      child: isGrid ? _buildGridCard(note, db) : _buildListCard(note, db),
    );
  }

  /// Handle note tap: select on desktop (master-detail), navigate on phone.
  void _onNoteTap(String noteId) {
    if (_isWideScreen) {
      setState(() => _selectedNoteId = noteId);
    } else {
      context.push('/notes/$noteId');
    }
  }

  /// List-view card for a note with warm tap feedback and theme-aware text.
  Widget _buildListCard(Note note, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = note.plainTitle ?? l10n.untitled;
    final preview = note.plainContent != null && note.plainContent!.length > 100
        ? '${note.plainContent!.substring(0, 100)}...'
        : note.plainContent ?? '';
    final time = _formatTime(note.updatedAt);
    final tags = _tagsCache[note.id] ?? [];
    final isSelected = _selectedNoteId == note.id;

    return Semantics(
      label: A11yUtils.noteCardLabel(
        title: title,
        timeDescription: time,
        isPinned: note.isPinned,
        isSynced: note.isSynced,
      ),
      button: true,
      child: Card(
        color: isSelected
            ? colorScheme.primaryContainer.withAlpha(80)
            : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onNoteTap(note.id),
            onLongPress: () => _showNoteContextMenu(context, note, db),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            splashColor: colorScheme.primary.withAlpha(25),
            highlightColor: colorScheme.primary.withAlpha(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with pin icon and sync badge.
                  Row(
                    children: [
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SyncStatusBadge(isSynced: note.isSynced),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Preview text (max 2 lines, warm secondary color).
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                  if (tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildTagChips(tags),
                    ),
                  const SizedBox(height: 6),
                  // Date with caption style and warm tertiary color.
                  Text(
                    time,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(115),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Grid-view card for a note with warm tap feedback and theme-aware text.
  Widget _buildGridCard(Note note, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = note.plainTitle ?? l10n.untitled;
    final preview = note.plainContent != null && note.plainContent!.length > 80
        ? '${note.plainContent!.substring(0, 80)}...'
        : note.plainContent ?? '';
    final time = _formatTime(note.updatedAt);
    final tags = _tagsCache[note.id] ?? [];
    final isSelected = _selectedNoteId == note.id;

    return Semantics(
      label: A11yUtils.noteCardLabel(
        title: title,
        timeDescription: time,
        isPinned: note.isPinned,
        isSynced: note.isSynced,
      ),
      button: true,
      child: Card(
        color: isSelected
            ? colorScheme.primaryContainer.withAlpha(80)
            : null,
        margin: const EdgeInsets.all(4),
        child: InkWell(
          onTap: () => _onNoteTap(note.id),
          onLongPress: () => _showNoteContextMenu(context, note, db),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          splashColor: colorScheme.primary.withAlpha(25),
          highlightColor: colorScheme.primary.withAlpha(15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with pin icon and sync badge.
                Row(
                  children: [
                    if (note.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.push_pin,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SyncStatusBadge(isSynced: note.isSynced),
                  ],
                ),
                const SizedBox(height: 8),
                // Preview text (max 4 lines, warm secondary color).
                Expanded(
                  child: Text(
                    preview,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _buildTagChips(tags),
                  ),
                const SizedBox(height: 4),
                // Date with warm tertiary color.
                Text(
                  time,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(115),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build up to 3 tag chips with warm fill and border styling.
  Widget _buildTagChips(List<Tag> tags) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayTags = tags.take(3).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: displayTags.map((tag) {
        return Semantics(
          label: A11yUtils.semanticLabelForTag(name: tag.plainName ?? '...'),
          child: Chip(
          label: Text(
            tag.plainName ?? '...',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(153),
            ),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          side: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(100),
            width: 0.5,
          ),
          backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(80),
        ),
        );
      }).toList(),
    );
  }

  /// Show a context menu with Pin/Unpin option on long press.
  void _showNoteContextMenu(
    BuildContext context,
    Note note,
    AppDatabase db,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: note.isPinned ? l10n.unpinNote : l10n.pinNote,
              child: ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(note.isPinned ? l10n.unpinNote : l10n.pinNote),
              onTap: () async {
                await db.notesDao.togglePin(note.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              ),
            ),
            Semantics(
              button: true,
              label: l10n.deleteNote,
              child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.deleteNote),
              onTap: () async {
                Navigator.of(ctx).pop();
                await db.notesDao.softDeleteNote(note.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.noteDeleted),
                      action: SnackBarAction(
                        label: l10n.undo,
                        onPressed: () async {
                          await (db.update(db.notes)
                                ..where((n) => n.id.equals(note.id)))
                              .write(const NotesCompanion(
                            deletedAt: Value(null),
                            isSynced: Value(false),
                          ),);
                        },
                      ),
                    ),
                  );
                }
              },
              ),
            ),
          ],
        ),
      ),
    );
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
            if (mounted) Navigator.pop(context);
            return;
          }
          result = await mdImporter.importFromDirectory(Directory(dirPath));

        case ImportType.text:
          final dirPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: l10n.importTextFiles,
          );
          if (dirPath == null) {
            if (mounted) Navigator.pop(context);
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
            if (mounted) Navigator.pop(context);
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

      if (!mounted) return;

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
      if (!mounted) return;
      // Close progress dialog.
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
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
      builder: (_) => TemplatePicker(
        onSelected: (content) {
          // Navigate to the note editor with the template content.
          // We pass the content via the query parameter.
          context.push('/notes/new?templateContent=${Uri.encodeComponent(content)}');
        },
      ),
    );
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

/// Placeholder shown in the detail pane when no note is selected on desktop.
class _InlineDetailPlaceholder extends StatelessWidget {
  const _InlineDetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Select a note to view',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

/// Inline note detail widget for the master-detail layout on desktop.
///
/// Loads and decrypts the note content, then renders it as Markdown
/// (similar to NoteDetailScreen but without its own Scaffold).
class _InlineNoteDetail extends ConsumerStatefulWidget {
  final String noteId;
  final AppDatabase db;
  final CryptoService crypto;

  const _InlineNoteDetail({
    required this.noteId,
    required this.db,
    required this.crypto,
  });

  @override
  ConsumerState<_InlineNoteDetail> createState() => _InlineNoteDetailState();
}

class _InlineNoteDetailState extends ConsumerState<_InlineNoteDetail> {
  _DecryptedNote? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void didUpdateWidget(_InlineNoteDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final note = await widget.db.notesDao.getNoteById(widget.noteId);
      if (!mounted) return;
      if (note == null) {
        setState(() {
          _data = null;
          _isLoading = false;
        });
        return;
      }

      final l10n = AppLocalizations.of(context)!;
      String title = note.plainTitle ?? l10n.untitled;
      String content = note.plainContent ?? '';

      if (widget.crypto.isUnlocked) {
        final decryptedContent =
            await widget.crypto.decryptForItem(widget.noteId, note.encryptedContent);
        if (decryptedContent != null) {
          content = decryptedContent;
        }
        if (note.encryptedTitle != null) {
          final decryptedTitle =
              await widget.crypto.decryptForItem(widget.noteId, note.encryptedTitle!);
          if (decryptedTitle != null) {
            title = decryptedTitle;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _data = _DecryptedNote(
          title: title,
          content: content,
          updatedAt: note.updatedAt,
          isSynced: note.isSynced,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(l10n.failedToLoadNote, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _loadNote, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return Center(child: Text(l10n.noteNotFound));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini toolbar for the detail pane
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _data!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: l10n.editNote,
                onPressed: () => context.push('/notes/${widget.noteId}'),
              ),
              IconButton(
                icon: const Icon(Icons.history, size: 20),
                tooltip: l10n.versionHistory,
                onPressed: () => context.push('/notes/${widget.noteId}/history'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${_data!.updatedAt.toLocal().toString().substring(0, 16)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (!_data!.isSynced) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.cloud_off, size: 14, color: Colors.orange.shade300),
                      const SizedBox(width: 4),
                      Text(l10n.notSynced, style: TextStyle(fontSize: 12, color: Colors.orange.shade300)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: _data!.content,
                  selectable: true,
                  // ignore: deprecated_member_use
                  imageBuilder: (uri, title, alt) {
                    if (uri.scheme == 'file') {
                      return Image.file(
                        File.fromUri(uri),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                      );
                    }
                    return Image.network(uri.toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),);
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.6),
                    h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    code: TextStyle(
                      fontSize: 13,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    blockquote: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple data class for a decrypted note's display properties.
class _DecryptedNote {
  final String title;
  final String content;
  final DateTime updatedAt;
  final bool isSynced;

  _DecryptedNote({
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.isSynced,
  });
}

/// Staggered entrance animation for note cards.
///
/// Each card fades in and slides up slightly with a delay proportional to its
/// [index], creating a cascading reveal effect when the list first loads.
class _StaggeredCardEntrance extends StatefulWidget {
  final int index;
  final int staggerDelay;
  final Widget child;

  const _StaggeredCardEntrance({
    required this.index,
    required this.staggerDelay,
    required this.child,
  });

  @override
  State<_StaggeredCardEntrance> createState() => _StaggeredCardEntranceState();
}

class _StaggeredCardEntranceState extends State<_StaggeredCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger delay based on index.
    final delay = Duration(milliseconds: widget.staggerDelay * widget.index);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
