import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, NoteTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  /// Get all tags.
  Future<List<Tag>> getAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.plainName)]))
        .get();
  }

  /// Watch all tags (reactive).
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.plainName)]))
        .watch();
  }

  /// Create a new tag.
  ///
  /// [parentId] optionally sets the parent tag for hierarchical organization.
  Future<String> createTag({
    required String id,
    required String encryptedName,
    String? plainName,
    String? parentId,
  }) async {
    await into(tags).insert(
      TagsCompanion.insert(
        id: id,
        encryptedName: encryptedName,
        plainName: Value(plainName),
        parentId: Value(parentId),
      ),
    );
    return id;
  }

  /// Update a tag.
  Future<void> updateTag({
    required String id,
    String? encryptedName,
    String? plainName,
  }) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        encryptedName:
            encryptedName != null ? Value(encryptedName) : const Value.absent(),
        plainName: Value(plainName),
        isSynced: const Value(false),
      ),
    );
  }

  /// Delete a tag and all its note associations.
  Future<void> deleteTag(String id) async {
    await (delete(noteTags)..where((nt) => nt.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  /// Get tags for a specific note.
  Future<List<Tag>> getTagsForNote(String noteId) async {
    final noteTagRows =
        await (select(noteTags)..where((nt) => nt.noteId.equals(noteId))).get();

    final tagIds = noteTagRows.map((nt) => nt.tagId).toList();
    if (tagIds.isEmpty) return [];

    return (select(tags)..where((t) => t.id.isIn(tagIds))).get();
  }

  /// Get unsynced tags.
  Future<List<Tag>> getUnsyncedTags() {
    return (select(tags)..where((t) => t.isSynced.equals(false))).get();
  }

  /// Mark tag as synced.
  Future<void> markSynced(String id) async {
    await (update(tags)..where((t) => t.id.equals(id)))
        .write(const TagsCompanion(isSynced: Value(true)));
  }

  /// Update the color of a tag. Pass null to remove the color.
  Future<void> updateTagColor(String id, String? color) async {
    await (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(color: Value(color)));
  }

  /// Watch all tags ordered by name (used by tree builder).
  Stream<List<Tag>> watchAllTagsOrdered() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.plainName)]))
        .watch();
  }

  /// Get direct children of a tag.
  Future<List<Tag>> getChildTags(String parentId) {
    return (select(tags)..where((t) => t.parentId.equals(parentId))).get();
  }

  /// Recursively get all descendant tag IDs of a given tag.
  Future<Set<String>> getDescendantTagIds(String tagId) async {
    final result = <String>{};
    await _collectDescendants(tagId, result);
    return result;
  }

  Future<void> _collectDescendants(
    String parentId,
    Set<String> result,
  ) async {
    final children =
        await (select(tags)..where((t) => t.parentId.equals(parentId))).get();
    for (final child in children) {
      if (result.add(child.id)) {
        await _collectDescendants(child.id, result);
      }
    }
  }

  /// Move a tag to a new parent. Pass null to make it root-level.
  /// Throws ArgumentError if the new parent would create a cycle.
  Future<void> reparentTag(String tagId, String? newParentId) async {
    if (newParentId == null) {
      // Moving to root is always safe.
      await (update(tags)..where((t) => t.id.equals(tagId)))
          .write(const TagsCompanion(parentId: Value(null)));
      return;
    }

    // Prevent setting self as parent.
    if (tagId == newParentId) {
      throw ArgumentError('A tag cannot be its own parent');
    }

    // Prevent circular reference: newParentId must not be a descendant of tagId.
    final descendants = await getDescendantTagIds(tagId);
    if (descendants.contains(newParentId)) {
      throw ArgumentError(
        'Cannot move a tag under one of its own descendants',
      );
    }

    await (update(tags)..where((t) => t.id.equals(tagId)))
        .write(TagsCompanion(parentId: Value(newParentId)));
  }

  /// Get the full path from root to this tag as a list of Tag objects.
  Future<List<Tag>> getTagPath(String tagId) async {
    final path = <Tag>[];
    String? currentId = tagId;
    final allTags = await getAllTags();
    final tagMap = {for (final t in allTags) t.id: t};

    // Safety limit to prevent infinite loops in case of data corruption.
    int maxDepth = 100;
    while (currentId != null && maxDepth > 0) {
      final tag = tagMap[currentId];
      if (tag == null) break;
      path.insert(0, tag);
      currentId = tag.parentId;
      maxDepth--;
    }
    return path;
  }
}
