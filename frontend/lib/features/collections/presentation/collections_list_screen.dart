import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/color_utils.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/color_picker_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sync_status_badge.dart';
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

  final Map<String, int> _noteCountCache = {};

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.newCollection,
            onPressed: () => _showCreateCollectionDialog(context, db),
          ),
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
            return _buildErrorState(l10n);
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
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.lightErrorBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 28,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.failedToLoadCollection,
            style: AppTextStyles.body.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: () => setState(() {}),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<Collection> collections, AppDatabase db) {
    return ListView.builder(
      itemCount: collections.length,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        80,
      ),
      itemBuilder: (context, index) {
        final collection = collections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: _buildDismissibleCard(collection, db, isGrid: false),
        );
      },
    );
  }

  Widget _buildGridView(List<Collection> collections, AppDatabase db) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent = constraints.maxWidth > 1200
            ? 280.0
            : constraints.maxWidth > 800
                ? 320.0
                : 360.0;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: AppSpacing.s8,
            crossAxisSpacing: AppSpacing.s8,
            childAspectRatio: 0.9,
          ),
          itemCount: collections.length,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.s4,
            AppSpacing.md,
            80,
          ),
          itemBuilder: (context, index) {
            final collection = collections[index];
            return _buildDismissibleCard(collection, db, isGrid: true);
          },
        );
      },
    );
  }

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
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.delete, color: AppColors.error.withAlpha(150)),
        ),
        confirmDismiss: (direction) async {
          final l10n = AppLocalizations.of(context)!;
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              title: Text(l10n.deleteCollectionQuestion),
              content: Text(
                l10n.deleteCollectionConfirm(
                  collection.plainTitle ?? l10n.untitledCollection,
                ),
                style: AppTextStyles.body,
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

  Widget _buildListCard(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    final noteCount = _noteCountCache[collection.id] ?? 0;
    final colColor = parseHexColor(collection.color);

    final accentBg = colColor?.withAlpha(25) ??
        (isDark ? AppColors.darkInputFill : AppColors.lightInputFill);

    return GestureDetector(
      onTap: () => context.push('/collections/${collection.id}'),
      onLongPress: () => _showCollectionEditMenu(collection, db),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.smOf(Theme.of(context).brightness),
        ),
        child: Row(
          children: [
            // Folder icon in tinted circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.folder,
                color: colColor ?? AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            // Title + note count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.noteCount(noteCount),
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Color dot + sync badge
            if (colColor != null)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: AppSpacing.s8),
                decoration: BoxDecoration(
                  color: colColor,
                  shape: BoxShape.circle,
                ),
              ),
            SyncStatusBadge(isSynced: collection.isSynced),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = collection.plainTitle ?? l10n.untitledCollection;
    final noteCount = _noteCountCache[collection.id] ?? 0;
    final colColor = parseHexColor(collection.color);

    final accentBg = colColor?.withAlpha(25) ??
        (isDark ? AppColors.darkInputFill : AppColors.lightInputFill);

    return GestureDetector(
      onTap: () => context.push('/collections/${collection.id}'),
      onLongPress: () => _showCollectionEditMenu(collection, db),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.smOf(Theme.of(context).brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder icon in tinted badge + sync badge
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.folder,
                    color: colColor ?? AppColors.primary,
                    size: 18,
                  ),
                ),
                const Spacer(),
                if (colColor != null)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: AppSpacing.s4),
                    decoration: BoxDecoration(
                      color: colColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                SyncStatusBadge(isSynced: collection.isSynced),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            // Note count
            Text(
              l10n.noteCount(noteCount),
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionEditMenu(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  if (collection.color != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
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
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? AppColors.darkDivider.withAlpha(60)
                  : AppColors.lightDivider.withAlpha(80),
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(l10n.noteColor),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _editCollectionColor(collection, db);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
              ),
              title: Text(
                l10n.delete,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteCollection(collection, db);
              },
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }

  Future<void> _editCollectionColor(
    Collection collection,
    AppDatabase db,
  ) async {
    final selectedColor = await showColorPickerSheet(
      context,
      currentColor: collection.color,
    );
    if (selectedColor != null && mounted) {
      final newColor = selectedColor.isEmpty ? null : selectedColor;
      await db.collectionsDao.updateCollectionColor(collection.id, newColor);
    }
  }

  void _deleteCollection(Collection collection, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    db.collectionsDao.deleteCollection(collection.id);
    _noteCountCache.remove(collection.id);
    AppSnackBar.info(context, message: l10n.collectionDeleted);
  }

  void _showCreateCollectionDialog(BuildContext context, AppDatabase db) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.newCollection),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: l10n.collectionTitle,
            hintText: l10n.collectionTitleHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          scrollPadding: const EdgeInsets.only(bottom: 120),
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

              final id = _generateId();

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

  String _generateId() {
    return const Uuid().v4();
  }
}
