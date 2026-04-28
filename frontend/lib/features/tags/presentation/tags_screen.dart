import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/color_utils.dart';
import '../../../core/widgets/color_picker_sheet.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/app_database.dart';
import '../../tags/domain/tag_tree_item.dart';
import 'widgets/tag_reparent_sheet.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final _tagNameController = TextEditingController();

  /// Tracks which tag IDs are expanded in the tree view.
  final Set<String> _expandedTags = {};

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
        actions: [
          StreamBuilder<List<Tag>>(
            stream: db.tagsDao.watchAllTags(),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                tooltip: l10n.moreOptions,
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
      body: StreamBuilder<List<Tag>>(
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

          // Build hierarchical tree from flat tag list.
          final tree = buildTagTree(tags);
          final flatItems = flattenTagTree(tree);

          return RefreshIndicator(
            onRefresh: () async {
              await db.tagsDao.getAllTags();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: flatItems.length,
              itemBuilder: (context, index) {
                final item = flatItems[index];
                return _buildTagTile(db, item, l10n);
              },
            ),
          );
        },
      ),
      floatingActionButton: Semantics(
        button: true,
        label: l10n.newTag,
        child: FloatingActionButton(
          onPressed: () =>
              _showCreateDialog(db, ref.read(cryptoServiceProvider)),
          tooltip: l10n.newTag,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Build a single tree-row tile for a tag.
  Widget _buildTagTile(
    AppDatabase db,
    TagTreeItem item,
    AppLocalizations l10n,
  ) {
    final tag = item.tag;
    final tagColor = parseHexColor(tag.color);
    final indent = item.level * 24.0;
    final isExpanded = _expandedTags.contains(tag.id);

    return Semantics(
      label: l10n.tagItemSemanticLabel(tag.plainName ?? l10n.encrypted),
      hint: l10n.tagItemSemanticHint,
      child: InkWell(
        onLongPress: () => _showTagEditMenu(db, tag),
        child: Padding(
          padding: EdgeInsets.only(left: 16 + indent),
          child: Row(
            children: [
              // Expand/collapse toggle.
              SizedBox(
                width: 28,
                height: 48,
                child: item.hasChildren
                    ? IconButton(
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: isExpanded ? l10n.collapseAll : l10n.expandAll,
                        onPressed: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedTags.remove(tag.id);
                            } else {
                              _expandedTags.add(tag.id);
                            }
                          });
                        },
                      )
                    : const SizedBox(width: 28),
              ),
              const SizedBox(width: 4),
              // Color dot.
              if (tagColor != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.label_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              // Tag name.
              Expanded(
                child: Text(
                  tag.plainName ?? l10n.encrypted,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              // Delete button.
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => _deleteTag(db, tag),
                tooltip: l10n.delete,
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
        title: Text(l10n.newTag),
        content: TextField(
          controller: _tagNameController,
          decoration: InputDecoration(
            labelText: l10n.tagName,
            hintText: l10n.tagNameHint,
          ),
          autofocus: true,
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
                final encryptedName = await crypto.encryptForItem(tagId, name);
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

  /// Show create-sub-tag dialog with a pre-selected parent.
  void _showCreateSubTagDialog(
    AppDatabase db,
    CryptoService crypto,
    Tag parentTag,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (!crypto.isUnlocked) {
      AppSnackBar.error(context, message: l10n.unlockRequired);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.createSubTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.tagName} (${parentTag.plainName ?? l10n.encrypted} >)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagNameController,
              decoration: InputDecoration(
                labelText: l10n.tagName,
                hintText: l10n.tagNameHint,
              ),
              autofocus: true,
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
                final encryptedName = await crypto.encryptForItem(tagId, name);
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
              // Auto-expand parent so the new child is visible.
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

  /// Show edit menu with color picker, sub-tag creation, reparent, and delete
  /// options on long press.
  void _showTagEditMenu(AppDatabase db, Tag tag) {
    final l10n = AppLocalizations.of(context)!;
    final crypto = ref.read(cryptoServiceProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with tag name.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (tag.color != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Create sub-tag.
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.createSubTag),
              onTap: () {
                Navigator.of(ctx).pop();
                _showCreateSubTagDialog(db, crypto, tag);
              },
            ),
            // Move to parent (reparent).
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l10n.moveToParent),
              onTap: () {
                Navigator.of(ctx).pop();
                _showReparentSheet(db, tag);
              },
            ),
            // Color picker.
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
                  final newColor = selectedColor.isEmpty ? null : selectedColor;
                  await db.tagsDao.updateTagColor(tag.id, newColor);
                }
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
                _deleteTag(db, tag);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show the reparent bottom sheet for selecting a new parent tag.
  void _showReparentSheet(AppDatabase db, Tag tag) async {
    final allTags = await db.tagsDao.getAllTags();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
