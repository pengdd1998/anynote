import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/color_utils.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/color_picker_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../tags/domain/tag_tree_item.dart';
import 'widgets/tag_reparent_sheet.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final _tagNameController = TextEditingController();

  final Set<String> _expandedTags = {};

  /// Local filter query for the tag search field (UI-only filtering).
  String _searchQuery = '';

  @override
  void dispose() {
    _tagNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tagsTitle),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          StreamBuilder<List<Tag>>(
            stream: db.tagsDao.watchAllTags(),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                tooltip: l10n.moreOptions,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'expand_all',
                    child: Text(l10n.expandAll),
                  ),
                  PopupMenuItem(
                    value: 'collapse_all',
                    child: Text(l10n.collapseAll),
                  ),
                ],
                onSelected: (value) {
                  setState(() {
                    if (value == 'expand_all') {
                      _expandedTags.addAll(tags.map((t) => t.id));
                    } else if (value == 'collapse_all') {
                      _expandedTags.clear();
                    }
                  });
                },
              );
            },
          ),
          const SyncStatusWidget(),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(l10n),
          Expanded(
            child: StreamBuilder<List<Tag>>(
              stream: db.tagsDao.watchAllTags(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tags = snapshot.data ?? [];

                if (tags.isEmpty) {
                  return EmptyState(
                    icon: Icons.label_outline,
                    title: l10n.noTags,
                    subtitle: l10n.createTagsToOrganize,
                  );
                }

                final flatItems = _visibleItems(tags);

                if (flatItems.isEmpty) {
                  return Center(
                    child: Text(
                      'No tags found',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await db.tagsDao.getAllTags();
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.s4,
                      AppSpacing.md,
                      96,
                    ),
                    itemCount: flatItems.length,
                    itemBuilder: (context, index) {
                      final item = flatItems[index];
                      return _buildTagRow(item, l10n, db);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        button: true,
        label: l10n.newTag,
        child: FloatingActionButton(
          onPressed: () =>
              _showCreateDialog(db, ref.read(cryptoServiceProvider)),
          tooltip: l10n.newTag,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: const Icon(AppIcons.add),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search field (mockup style: pill, input fill, magnifier)
  // ---------------------------------------------------------------------------

  Widget _buildSearchField(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final fill = isDark ? AppColors.darkInputFill : AppColors.lightInputFill;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.s8,
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search tags...',
          hintStyle: AppTextStyles.body.copyWith(color: tertiary),
          prefixIcon: Icon(AppIcons.search, size: 20, color: tertiary),
          isDense: true,
          filled: true,
          fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  /// Visible tree items: full hierarchy respecting the expanded set, or a flat
  /// name-filtered list while searching.
  List<TagTreeItem> _visibleItems(List<Tag> tags) {
    final tree = buildTagTree(tags);
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      return flattenTagTree(tree)
          .where((item) => (item.tag.plainName ?? '')
              .toLowerCase()
              .contains(query),)
          .toList();
    }

    // Depth-first walk that only descends into expanded nodes.
    final result = <TagTreeItem>[];
    void walk(List<TagTreeItem> items) {
      for (final item in items) {
        result.add(item);
        if (_expandedTags.contains(item.tag.id)) {
          walk(item.children);
        }
      }
    }

    walk(tree);
    return result;
  }

  Widget _buildTagRow(
    TagTreeItem item,
    AppLocalizations l10n,
    AppDatabase db,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tag = item.tag;
    final tagColor = parseHexColor(tag.color);
    final indent = item.level * 20.0;
    final isExpanded = _expandedTags.contains(tag.id);
    final hasChildren = item.hasChildren;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: GestureDetector(
        onLongPress: () => _showTagEditMenu(db, tag),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Expand/collapse caret (only for rows with children)
              if (hasChildren)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTags.remove(tag.id);
                      } else {
                        _expandedTags.add(tag.id);
                      }
                    });
                  },
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        AppIcons.chevronRight,
                        size: 16,
                        color: tertiary,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 24),
              // Optional tag color dot
              if (tagColor != null)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: tagColor,
                    shape: BoxShape.circle,
                  ),
                ),
              // "# name"
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '# ',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: tertiary,
                        ),
                      ),
                      TextSpan(
                        text: tag.plainName ?? l10n.encrypted,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Child count (right-aligned caption)
              if (hasChildren) ...[
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '${item.children.length}',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: tertiary,
                  ),
                ),
              ],
              // Delete button
              GestureDetector(
                onTap: () => _deleteTag(db, tag),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.error.withAlpha(150),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(AppDatabase db, CryptoService crypto) {
    final l10n = AppLocalizations.of(context)!;

    if (!crypto.isUnlocked) {
      AppSnackBar.error(context, message: l10n.unlockRequired);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.newTag),
        content: TextField(
          controller: _tagNameController,
          decoration: InputDecoration(
            labelText: l10n.tagName,
            hintText: l10n.tagNameHint,
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
            onPressed: () {
              Navigator.pop(ctx);
              _tagNameController.clear();
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = _tagNameController.text.trim();
              if (name.isNotEmpty) {
                final tagId = const Uuid().v4();
                final encryptedName =
                    await crypto.encryptForItem(tagId, name);
                await db.tagsDao.createTag(
                  id: tagId,
                  encryptedName: encryptedName,
                  plainName: name,
                );
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _tagNameController.clear();
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  void _showCreateSubTagDialog(
    AppDatabase db,
    CryptoService crypto,
    Tag parentTag,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!crypto.isUnlocked) {
      AppSnackBar.error(context, message: l10n.unlockRequired);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.createSubTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: (isDark
                        ? AppColors.darkInputFill
                        : AppColors.lightInputFill)
                    .withAlpha(180),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                '${parentTag.plainName ?? l10n.encrypted} >',
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: _tagNameController,
              decoration: InputDecoration(
                labelText: l10n.tagName,
                hintText: l10n.tagNameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              scrollPadding: const EdgeInsets.only(bottom: 120),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tagNameController.clear();
            },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = _tagNameController.text.trim();
              if (name.isNotEmpty) {
                final tagId = const Uuid().v4();
                final encryptedName =
                    await crypto.encryptForItem(tagId, name);
                await db.tagsDao.createTag(
                  id: tagId,
                  encryptedName: encryptedName,
                  plainName: name,
                  parentId: parentTag.id,
                );
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              _tagNameController.clear();
              setState(() {
                _expandedTags.add(parentTag.id);
              });
            },
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  void _showTagEditMenu(AppDatabase db, Tag tag) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crypto = ref.read(cryptoServiceProvider);

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
            // Header with tag name
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  if (tag.color != null)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.s8),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: parseHexColor(tag.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      tag.plainName ?? l10n.encrypted,
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
              leading: const Icon(Icons.add),
              title: Text(l10n.createSubTag),
              onTap: () {
                Navigator.of(ctx).pop();
                _showCreateSubTagDialog(db, crypto, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l10n.moveToParent),
              onTap: () {
                Navigator.of(ctx).pop();
                _showReparentSheet(db, tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: Text(l10n.noteColor),
              onTap: () async {
                Navigator.of(ctx).pop();
                final selectedColor = await showColorPickerSheet(
                  context,
                  currentColor: tag.color,
                );
                if (selectedColor != null && mounted) {
                  final newColor =
                      selectedColor.isEmpty ? null : selectedColor;
                  await db.tagsDao.updateTagColor(tag.id, newColor);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteTag(db, tag);
              },
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }

  void _showReparentSheet(AppDatabase db, Tag tag) async {
    final allTags = await db.tagsDao.getAllTags();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: TagReparentSheet(
            allTags: allTags,
            tagId: tag.id,
            onSelected: (newParentId) async {
              try {
                await db.tagsDao.reparentTag(tag.id, newParentId);
              } on ArgumentError catch (e) {
                if (mounted) {
                  AppSnackBar.error(
                    context,
                    message: e.message.toString(),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  void _deleteTag(AppDatabase db, Tag tag) {
    db.tagsDao.deleteTag(tag.id);
  }
}
