import 'package:collection/collection.dart';

import '../../../core/database/app_database.dart';

/// A tag node in a hierarchical tree structure.
///
/// [level] indicates the nesting depth (0 = root). Each node carries its
/// [Tag] database row and a list of child [TagTreeItem]s.
class TagTreeItem {
  final Tag tag;
  final List<TagTreeItem> children;
  final int level;

  const TagTreeItem({
    required this.tag,
    this.children = const [],
    this.level = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagTreeItem &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          const DeepCollectionEquality().equals(children, other.children) &&
          level == other.level;

  @override
  int get hashCode => Object.hash(tag, Object.hashAll(children), level);

  /// Whether this node has any children.
  bool get hasChildren => children.isNotEmpty;
}

/// Builds a flat list of [Tag] rows into a hierarchical tree of [TagTreeItem]s.
///
/// Tags with no [Tag.parentId] (or a parentId not found in the list) are
/// treated as root nodes. Returns a list of root-level [TagTreeItem]s.
List<TagTreeItem> buildTagTree(List<Tag> flatTags) {
  final tagMap = <String, _BuildNode>{};
  for (final tag in flatTags) {
    tagMap[tag.id] = _BuildNode(tag: tag);
  }

  final roots = <TagTreeItem>[];

  // First pass: collect children under their parents.
  for (final tag in flatTags) {
    final parentId = tag.parentId;
    if (parentId == null || !tagMap.containsKey(parentId)) {
      // Root-level tag.
      roots.add(tagMap[tag.id]!.toTreeItem(0));
    } else {
      tagMap[parentId]!.childIds.add(tag.id);
    }
  }

  // Recursive builder that also sets children on the items.
  List<TagTreeItem> buildChildren(_BuildNode node, int level) {
    final items = <TagTreeItem>[];
    for (final childId in node.childIds) {
      final childNode = tagMap[childId];
      if (childNode != null) {
        final childLevel = level + 1;
        // Recursively attach grandchildren.
        final grandchildren = buildChildren(childNode, childLevel);
        items.add(
          TagTreeItem(
            tag: childNode.tag,
            children: grandchildren,
            level: childLevel,
          ),
        );
      }
    }
    return items;
  }

  // Attach children to root items.
  final result = <TagTreeItem>[];
  for (final root in roots) {
    final node = tagMap[root.tag.id]!;
    final children = buildChildren(node, 0);
    result.add(
      TagTreeItem(
        tag: root.tag,
        children: children,
        level: 0,
      ),
    );
  }

  return result;
}

/// Mutable helper used only during tree construction.
class _BuildNode {
  final Tag tag;
  final List<String> childIds = [];

  _BuildNode({required this.tag});

  TagTreeItem toTreeItem(int level) => TagTreeItem(tag: tag, level: level);
}

/// Flattens a tree of [TagTreeItem]s into a depth-first list.
List<TagTreeItem> flattenTagTree(List<TagTreeItem> tree) {
  final result = <TagTreeItem>[];
  for (final item in tree) {
    result.add(item);
    result.addAll(flattenTagTree(item.children));
  }
  return result;
}
