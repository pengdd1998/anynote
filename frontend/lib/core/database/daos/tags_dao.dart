import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, NoteTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  /// Get all tags.
  Future<List<Tag>> getAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.plainName)])).get();
  }

  /// Watch all tags (reactive).
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.plainName)])).watch();
  }

  /// Create a new tag.
  Future<String> createTag({
    required String id,
    required String encryptedName,
    String? plainName,
  }) async {
    await into(tags).insert(TagsCompanion.insert(
      id: id,
      encryptedName: encryptedName,
      plainName: Value(plainName),
    ));
    return id;
  }

  /// Update a tag.
  Future<void> updateTag({
    required String id,
    String? encryptedName,
    String? plainName,
  }) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(TagsCompanion(
      encryptedName: Value(encryptedName),
      plainName: Value(plainName),
      isSynced: const Value(false),
    ));
  }

  /// Delete a tag and all its note associations.
  Future<void> deleteTag(String id) async {
    await (delete(noteTags)..where((nt) => nt.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  /// Get tags for a specific note.
  Future<List<Tag>> getTagsForNote(String noteId) async {
    final noteTagRows = await (select(noteTags)
          ..where((nt) => nt.noteId.equals(noteId)))
        .get();

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
}
