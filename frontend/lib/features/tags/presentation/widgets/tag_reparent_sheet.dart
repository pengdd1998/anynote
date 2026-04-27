import 'package:flutter/material.dart';

import '../../../../core/theme/color_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/tag_tree_item.dart';

/// Bottom sheet for selecting a new parent tag when reparenting.
///
/// Shows a searchable list of all tags in a tree layout. The tag being
/// reparented is excluded to prevent circular references. Selecting a tag
/// calls [onSelected] with the new parentId. The "No Parent (Root)" option
/// at the top calls [onSelected] with null.
class TagReparentSheet extends StatefulWidget {
  /// All tags currently in the database.
  final List<Tag> allTags;

  /// The ID of the tag being reparented (excluded from the list).
  final String tagId;

  /// Called with the new parent tag ID, or null for root-level.
  final void Function(String? newParentId) onSelected;

  const TagReparentSheet({
    super.key,
    required this.allTags,
    required this.tagId,
    required this.onSelected,
  });

  @override
  State<TagReparentSheet> createState() => _TagReparentSheetState();
}

class _TagReparentSheetState extends State<TagReparentSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Exclude the tag being reparented and its descendants from the list
    // to prevent circular references.
    final excludedIds = _getExcludedIds();
    final availableTags =
        widget.allTags.where((t) => !excludedIds.contains(t.id)).toList();

    // Build tree from available tags.
    final tree = buildTagTree(availableTags);

    // Flatten for search filtering.
    final flatItems = flattenTagTree(tree);
    final filteredItems = _query.isEmpty
        ? flatItems
        : flatItems
            .where(
              (item) => (item.tag.plainName ?? '')
                  .toLowerCase()
                  .contains(_query.toLowerCase()),
            )
            .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(colorScheme: theme.colorScheme),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.selectParentTag,
              style: theme.textTheme.titleMedium,
            ),
          ),
          _SearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            l10n: l10n,
          ),
          _NoParentOption(
            l10n: l10n,
            theme: theme,
            onTap: () {
              widget.onSelected(null);
              Navigator.of(context).pop();
            },
          ),
          const Divider(height: 1),
          Flexible(
            child: _TagTreeList(
              filteredItems: filteredItems,
              onTagSelected: (tagId) {
                widget.onSelected(tagId);
                Navigator.of(context).pop();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Returns the set of IDs that should be excluded from selection:
  /// the tag itself plus all its descendants.
  Set<String> _getExcludedIds() {
    final excluded = <String>{widget.tagId};
    _collectDescendants(widget.tagId, excluded);
    return excluded;
  }

  void _collectDescendants(String parentId, Set<String> result) {
    for (final tag in widget.allTags) {
      if (tag.parentId == parentId && result.add(tag.id)) {
        _collectDescendants(tag.id, result);
      }
    }
  }
}

/// Drag handle bar at the top of the bottom sheet.
class _DragHandle extends StatelessWidget {
  final ColorScheme colorScheme;

  const _DragHandle({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Search field for filtering tags by name.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: l10n.search,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// "No Parent (Root)" option that sets the parent to null.
class _NoParentOption extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final VoidCallback onTap;

  const _NoParentOption({
    required this.l10n,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.folder_open, color: theme.colorScheme.primary),
      title: Text(
        l10n.noParent,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Scrollable list of tag tree items with indentation and color indicators.
class _TagTreeList extends StatelessWidget {
  final List<TagTreeItem> filteredItems;
  final ValueChanged<String> onTagSelected;

  const _TagTreeList({
    required this.filteredItems,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: filteredItems.length,
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _TagTreeTile(item: item, onSelected: onTagSelected);
      },
    );
  }
}

/// A single tile in the tag tree with indentation and color indicator.
class _TagTreeTile extends StatelessWidget {
  final TagTreeItem item;
  final ValueChanged<String> onSelected;

  const _TagTreeTile({required this.item, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final indent = item.level * 16.0;
    final tagColor = parseHexColor(item.tag.color);

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 16),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.level > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          if (tagColor != null)
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tagColor,
                shape: BoxShape.circle,
              ),
            )
          else
            Icon(
              Icons.label_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
      title: Text(item.tag.plainName ?? l10n.encrypted),
      onTap: () => onSelected(item.tag.id),
    );
  }
}
