import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/widgets/empty_state.dart';
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCollectionDialog(context, db),
        child: const Icon(Icons.add),
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
    return Dismissible(
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
              l10n.deleteCollectionConfirm(collection.plainTitle ?? l10n.untitledCollection),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.collectionDeleted)),
        );
      },
      child: isGrid
          ? _buildGridCard(collection)
          : _buildListCard(collection),
    );
  }

  /// List-view card for a collection.
  Widget _buildListCard(Collection collection) {
    final l10n = AppLocalizations.of(context)!;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    final noteCount = _noteCountCache[collection.id] ?? 0;

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
              Icon(Icons.note_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                l10n.noteCount(noteCount),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        trailing: SyncStatusBadge(isSynced: collection.isSynced),
        leading: const Icon(Icons.folder),
        onTap: () => context.push('/collections/${collection.id}'),
      ),
    );
  }

  /// Grid-view card for a collection.
  Widget _buildGridCard(Collection collection) {
    final l10n = AppLocalizations.of(context)!;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    final noteCount = _noteCountCache[collection.id] ?? 0;

    return Card(
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: () => context.push('/collections/${collection.id}'),
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
                    color: Theme.of(context).colorScheme.primary,
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
                  Icon(Icons.note_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    l10n.noteCount(noteCount),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                encryptedTitle =
                    await crypto.encryptForItem(id, title);
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
