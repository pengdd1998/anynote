import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionDetailScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  /// The collection data, loaded once and refreshed on changes.
  Collection? _collection;

  /// Notes belonging to this collection, with sortOrder.
  List<CollectionNote> _collectionNotes = [];

  /// Full note objects for the notes in this collection, keyed by ID.
  Map<String, Note> _notesMap = {};

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load the collection and its notes from the database.
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseProvider);

      // Load the collection.
      final collections = await db.collectionsDao.getAllCollections();
      final collection =
          collections.where((c) => c.id == widget.collectionId).firstOrNull;
      if (collection == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'collectionNotFound'; // will be translated in _buildBody
          });
        }
        return;
      }

      // Load collection-note associations.
      final collectionNotes =
          await db.collectionsDao.getCollectionNotes(widget.collectionId);

      // Load full note data for each note in the collection.
      final Map<String, Note> notesMap = {};
      for (final cn in collectionNotes) {
        final note = await db.notesDao.getNoteById(cn.noteId);
        if (note != null && note.deletedAt == null) {
          notesMap[cn.noteId] = note;
        }
      }

      if (mounted) {
        setState(() {
          _collection = collection;
          _collectionNotes = collectionNotes;
          _notesMap = notesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_collection?.plainTitle ?? l10n.collectionFallback),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.renameCollectionTooltip,
            onPressed:
                _collection != null ? () => _showRenameDialog(context) : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deleteCollectionTooltip,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNotesSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final displayError = _error == 'collectionNotFound'
          ? l10n.collectionNotFound
          : l10n.failedToLoadCollection;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              displayError,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadData,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    // Filter out notes that have been deleted or are missing from the map.
    final validNotes = _collectionNotes
        .where((cn) => _notesMap.containsKey(cn.noteId))
        .toList();

    if (validNotes.isEmpty) {
      return EmptyState(
        icon: Icons.note_add_outlined,
        title: l10n.noNotesInCollection,
        subtitle: l10n.tapToAddNotes,
        actionLabel: l10n.addNotes,
        onAction: _showAddNotesSheet,
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: validNotes.length,
      onReorder: (oldIndex, newIndex) =>
          _onReorder(validNotes, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final cn = validNotes[index];
        final note = _notesMap[cn.noteId]!;
        final title = note.plainTitle ?? l10n.untitled;

        return Dismissible(
          key: ValueKey(cn.noteId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Colors.orange,
            child: const Icon(Icons.remove_circle_outline, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.removeFromCollection),
                content: Text(
                  l10n.removeNoteConfirm(title),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(l10n.remove),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            final db = ref.read(databaseProvider);
            await db.collectionsDao.removeNoteFromCollection(
              widget.collectionId,
              cn.noteId,
            );
            _loadData();
          },
          child: ListTile(
            key: ValueKey(cn.noteId),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: note.plainContent != null && note.plainContent!.isNotEmpty
                ? Text(
                    note.plainContent!.length > 80
                        ? '${note.plainContent!.substring(0, 80)}...'
                        : note.plainContent!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,),
                  )
                : null,
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: l10n.removeFromCollectionTooltip,
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.collectionsDao.removeNoteFromCollection(
                  widget.collectionId,
                  cn.noteId,
                );
                _loadData();
              },
            ),
            onTap: () => context.push('/notes/${cn.noteId}'),
          ),
        );
      },
    );
  }

  /// Handle reordering of notes within the collection.
  void _onReorder(
    List<CollectionNote> validNotes,
    int oldIndex,
    int newIndex,
  ) {
    // Adjust newIndex since ReorderableListView uses a different convention.
    if (oldIndex < newIndex) newIndex -= 1;

    setState(() {
      final item = validNotes.removeAt(oldIndex);
      validNotes.insert(newIndex, item);
    });

    // Persist the new sort order.
    _persistSortOrder(validNotes);
  }

  /// Persist the updated sort order to the database.
  Future<void> _persistSortOrder(List<CollectionNote> notes) async {
    final db = ref.read(databaseProvider);
    for (var i = 0; i < notes.length; i++) {
      final cn = notes[i];
      // Delete and re-insert with new sortOrder.
      await db.collectionsDao.removeNoteFromCollection(
        widget.collectionId,
        cn.noteId,
      );
      await db.collectionsDao.addNoteToCollection(
        collectionId: widget.collectionId,
        noteId: cn.noteId,
        sortOrder: i,
      );
    }
  }

  /// Show a dialog to rename the collection.
  void _showRenameDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(
      text: _collection?.plainTitle ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameCollection),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.collectionTitle,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isEmpty) return;

              final db = ref.read(databaseProvider);
              final crypto = ref.read(cryptoServiceProvider);

              String encryptedTitle = newTitle;
              if (crypto.isUnlocked) {
                encryptedTitle =
                    await crypto.encryptForItem(widget.collectionId, newTitle);
              }

              await db.collectionsDao.updateCollection(
                id: widget.collectionId,
                encryptedTitle: encryptedTitle,
                plainTitle: newTitle,
              );

              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadData();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  /// Confirm and delete the entire collection.
  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCollectionDialogTitle),
        content: Text(l10n.deleteCollectionDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.collectionsDao.deleteCollection(widget.collectionId);
              if (context.mounted) {
                Navigator.pop(ctx);
                context.pop();
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// Show a bottom sheet with all notes, allowing the user to add/remove
  /// notes from this collection.
  void _showAddNotesSheet() {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => FutureBuilder<List<Note>>(
          future: db.notesDao.getAllNotes(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allNotes = snapshot.data ?? [];

            // Track which notes are currently in the collection.
            final currentNoteIds =
                _collectionNotes.map((cn) => cn.noteId).toSet();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        l10n.addNotes,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: allNotes.isEmpty
                      ? Center(
                          child: Text(l10n.noNotesAvailable),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: allNotes.length,
                          itemBuilder: (ctx, index) {
                            final note = allNotes[index];
                            final isInCollection =
                                currentNoteIds.contains(note.id);
                            final title = note.plainTitle ?? 'Untitled';

                            return CheckboxListTile(
                              value: isInCollection,
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: note.plainContent != null &&
                                      note.plainContent!.isNotEmpty
                                  ? Text(
                                      note.plainContent!.length > 60
                                          ? '${note.plainContent!.substring(0, 60)}...'
                                          : note.plainContent!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              onChanged: (checked) async {
                                if (checked == true) {
                                  // Get the next sort order.
                                  final maxSort = _collectionNotes.isEmpty
                                      ? -1
                                      : _collectionNotes
                                          .map((cn) => cn.sortOrder)
                                          .reduce((a, b) => a > b ? a : b);
                                  await db.collectionsDao.addNoteToCollection(
                                    collectionId: widget.collectionId,
                                    noteId: note.id,
                                    sortOrder: maxSort + 1,
                                  );
                                } else {
                                  await db.collectionsDao
                                      .removeNoteFromCollection(
                                    widget.collectionId,
                                    note.id,
                                  );
                                }
                                // Reload data and rebuild the sheet.
                                await _loadData();
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
