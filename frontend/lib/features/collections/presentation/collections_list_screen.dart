import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/color_utils.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/widgets/color_picker_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../settings/data/settings_providers.dart';

class CollectionsListScreen extends ConsumerStatefulWidget {
  const CollectionsListScreen({super.key});

  @override
  ConsumerState<CollectionsListScreen> createState() =>
      _CollectionsListScreenState();
}

class _CollectionsListScreenState extends ConsumerState<CollectionsListScreen> {
  bool _isGridView = false;

  /// Cache of collection ID -> note count for displaying in cards.
  final Map<String, int> _noteCountCache = {};

  /// Load note count for a single collection and cache it.
  Future<void> _loadNoteCount(String collectionId, AppDatabase db) async {
    if (_noteCountCache.containsKey(collectionId)) return;
    final notes = await db.collectionsDao.getCollectionNotes(collectionId);
    if (mounted) {
      setState(() {
        _noteCountCache[collectionId] = notes.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.collectionsTitle),
        actions: [
          const SyncStatusWidget(),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? l10n.listView : l10n.gridView,
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: db.collectionsDao.watchAllCollections(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.failedToLoadCollection),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => setState(() {}),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final collections = snapshot.data ?? [];

          if (collections.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_outlined,
              title: l10n.noCollectionsYet,
              subtitle: l10n.groupNotesIntoCollections,
              actionLabel: l10n.newCollection,
              onAction: () => _showCreateCollectionDialog(context, db),
            );
          }

          // Trigger note count loading for visible collections.
          for (final collection in collections) {
            _loadNoteCount(collection.id, db);
          }

          return RefreshIndicator(
            onRefresh: () async {
              final notifier = ref.read(syncStatusProvider.notifier);
              await notifier.sync();
            },
            child: _isGridView
                ? _buildGridView(collections, db)
                : _buildListView(collections, db),
          );
        },
      ),
      floatingActionButton: Semantics(
        button: true,
        label: l10n.newCollection,
        child: FloatingActionButton(
          onPressed: () => _showCreateCollectionDialog(context, db),
          tooltip: l10n.newCollection,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildListView(List<Collection> collections, AppDatabase db) {
    return ListView.builder(
      itemCount: collections.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final collection = collections[index];
        return _buildDismissibleCard(collection, db, isGrid: false);
      },
    );
  }

  Widget _buildGridView(List<Collection> collections, AppDatabase db) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
      ),
      itemCount: collections.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final collection = collections[index];
        return _buildDismissibleCard(collection, db, isGrid: true);
      },
    );
  }

  /// Build a collection card wrapped in a Dismissible for swipe-to-delete.
  Widget _buildDismissibleCard(
    Collection collection,
    AppDatabase db, {
    required bool isGrid,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    return Semantics(
      label: l10n.noteSemantics(title),
      child: Dismissible(
        key: ValueKey(collection.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          final l10n = AppLocalizations.of(context)!;
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.deleteCollectionQuestion),
              content: Text(
                l10n.deleteCollectionConfirm(
                  collection.plainTitle ?? l10n.untitledCollection,
                ),
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
          final l10n = AppLocalizations.of(context)!;
          db.collectionsDao.deleteCollection(collection.id);
          _noteCountCache.remove(collection.id);
          AppSnackBar.info(context, message: l10n.collectionDeleted);
        },
        child: isGrid
            ? _buildGridCard(collection, db)
            : _buildListCard(collection, db),
      ),
    );
  }

  /// List-view card for a collection.
  Widget _buildListCard(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    final noteCount = _noteCountCache[collection.id] ?? 0;
    final colColor = parseHexColor(collection.color);

    return Card(
      child: ListTile(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.note_outlined,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),),
              const SizedBox(width: 4),
              Text(
                l10n.noteCount(noteCount),
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color edit button.
            if (colColor != null)
              IconButton(
                icon: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colColor,
                    shape: BoxShape.circle,
                  ),
                ),
                tooltip: l10n.noteColor,
                onPressed: () => _editCollectionColor(collection, db),
              ),
            SyncStatusBadge(isSynced: collection.isSynced),
          ],
        ),
        leading: Icon(
          Icons.folder,
          color: colColor,
        ),
        onTap: () => context.push('/collections/${collection.id}'),
        onLongPress: () => _showCollectionEditMenu(collection, db),
      ),
    );
  }

  /// Grid-view card for a collection.
  Widget _buildGridCard(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    final noteCount = _noteCountCache[collection.id] ?? 0;
    final colColor = parseHexColor(collection.color);

    return Card(
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: () => context.push('/collections/${collection.id}'),
        onLongPress: () => _showCollectionEditMenu(collection, db),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.folder,
                    color: colColor ?? Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SyncStatusBadge(isSynced: collection.isSynced),
                ],
              ),
              const SizedBox(height: 12),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.noteCount(noteCount),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),),
                  ),
                  const Spacer(),
                  // Color indicator dot.
                  if (colColor != null)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show edit menu with color picker option on long press.
  void _showCollectionEditMenu(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with collection name.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (collection.color != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: parseHexColor(collection.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      collection.plainTitle ?? l10n.untitledCollection,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(l10n.noteColor),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _editCollectionColor(collection, db);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteCollection(collection, db);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Open color picker for a collection.
  Future<void> _editCollectionColor(
    Collection collection,
    AppDatabase db,
  ) async {
    final selectedColor = await showColorPickerSheet(
      context,
      currentColor: collection.color,
    );
    if (selectedColor != null && mounted) {
      // Empty string means remove color.
      final newColor = selectedColor.isEmpty ? null : selectedColor;
      await db.collectionsDao.updateCollectionColor(collection.id, newColor);
    }
  }

  /// Delete a collection after confirmation.
  void _deleteCollection(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    db.collectionsDao.deleteCollection(collection.id);
    _noteCountCache.remove(collection.id);
    AppSnackBar.info(context, message: l10n.collectionDeleted);
  }

  /// Show a dialog to create a new collection.
  void _showCreateCollectionDialog(BuildContext context, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newCollection),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.collectionTitle,
            hintText: l10n.collectionTitleHint,
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
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              // Generate a UUID for the collection.
              final id = _generateId();

              // If crypto is unlocked, encrypt the title.
              final crypto = ref.read(cryptoServiceProvider);
              String encryptedTitle = title;
              if (crypto.isUnlocked) {
                encryptedTitle = await crypto.encryptForItem(id, title);
              }

              await db.collectionsDao.createCollection(
                id: id,
                encryptedTitle: encryptedTitle,
                plainTitle: title,
              );

              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  /// Generate a unique ID using UUID v4.
  String _generateId() {
    return const Uuid().v4();
  }
}
