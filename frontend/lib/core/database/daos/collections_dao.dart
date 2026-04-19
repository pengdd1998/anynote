import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'collections_dao.g.dart';

@DriftAccessor(tables: [Collections, CollectionNotes])
class CollectionsDao extends DatabaseAccessor<AppDatabase>
    with _$CollectionsDaoMixin {
  CollectionsDao(super.db);

  /// Get all collections.
  Future<List<Collection>> getAllCollections() {
    return (select(collections)..orderBy([(c) => OrderingTerm.asc(c.plainTitle)]))
        .get();
  }

  /// Watch all collections (reactive).
  Stream<List<Collection>> watchAllCollections() {
    return (select(collections)..orderBy([(c) => OrderingTerm.asc(c.plainTitle)]))
        .watch();
  }

  /// Create a new collection.
  Future<String> createCollection({
    required String id,
    required String encryptedTitle,
    String? plainTitle,
  }) async {
    await into(collections).insert(CollectionsCompanion.insert(
      id: id,
      encryptedTitle: encryptedTitle,
      plainTitle: Value(plainTitle),
    ),);
    return id;
  }

  /// Update a collection.
  Future<void> updateCollection({
    required String id,
    String? encryptedTitle,
    String? plainTitle,
  }) async {
    await (update(collections)..where((c) => c.id.equals(id)))
        .write(CollectionsCompanion(
      encryptedTitle: encryptedTitle != null ? Value(encryptedTitle) : const Value.absent(),
      plainTitle: Value(plainTitle),
      isSynced: const Value(false),
    ),);
  }

  /// Delete a collection and its note associations.
  Future<void> deleteCollection(String id) async {
    await (delete(collectionNotes)..where((cn) => cn.collectionId.equals(id))).go();
    await (delete(collections)..where((c) => c.id.equals(id))).go();
  }

  /// Add a note to a collection.
  Future<void> addNoteToCollection({
    required String collectionId,
    required String noteId,
    int sortOrder = 0,
  }) async {
    await into(collectionNotes).insert(CollectionNotesCompanion.insert(
      collectionId: collectionId,
      noteId: noteId,
      sortOrder: Value(sortOrder),
    ),);
  }

  /// Remove a note from a collection.
  Future<void> removeNoteFromCollection(String collectionId, String noteId) async {
    await (delete(collectionNotes)
          ..where((cn) =>
              cn.collectionId.equals(collectionId) & cn.noteId.equals(noteId),))
        .go();
  }

  /// Get notes in a collection, ordered by sortOrder.
  Future<List<CollectionNote>> getCollectionNotes(String collectionId) async {
    return (select(collectionNotes)
          ..where((cn) => cn.collectionId.equals(collectionId))
          ..orderBy([(cn) => OrderingTerm.asc(cn.sortOrder)]))
        .get();
  }

  /// Get unsynced collections.
  Future<List<Collection>> getUnsyncedCollections() {
    return (select(collections)..where((c) => c.isSynced.equals(false))).get();
  }

  /// Mark collection as synced.
  Future<void> markSynced(String id) async {
    await (update(collections)..where((c) => c.id.equals(id)))
        .write(const CollectionsCompanion(isSynced: Value(true)));
  }
}
