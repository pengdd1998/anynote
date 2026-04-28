import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'images_dao.g.dart';

/// Data access object for note image metadata.
/// Tracks image files, dimensions, hashes, and sync status.
@DriftAccessor(tables: [NoteImages])
class ImagesDao extends DatabaseAccessor<AppDatabase> with _$ImagesDaoMixin {
  ImagesDao(super.db);

  /// Insert a new image record.
  Future<void> insertImage(NoteImagesCompanion image) async {
    await into(noteImages).insert(image);
  }

  /// Insert or replace an image record (upsert by primary key).
  Future<void> upsertImage(NoteImagesCompanion image) async {
    await into(noteImages).insertOnConflictUpdate(image);
  }

  /// Get all images for a given note, ordered by creation time.
  Future<List<NoteImage>> getImagesForNote(String noteId) {
    return (select(noteImages)
          ..where((i) => i.noteId.equals(noteId))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
        .get();
  }

  /// Get a single image by its ID.
  Future<NoteImage?> getImageById(String id) {
    return (select(noteImages)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
  }

  /// Delete an image record by ID.
  Future<void> deleteImage(String id) async {
    await (delete(noteImages)..where((i) => i.id.equals(id))).go();
  }

  /// Delete all image records for a given note.
  Future<int> deleteImagesForNote(String noteId) async {
    return await (delete(noteImages)..where((i) => i.noteId.equals(noteId)))
        .go();
  }

  /// Get all images that have not yet been synced to the server.
  Future<List<NoteImage>> getUnsyncedImages() {
    return (select(noteImages)..where((i) => i.isSynced.equals(false))).get();
  }

  /// Mark an image as synced.
  Future<void> markSynced(String id) async {
    await (update(noteImages)..where((i) => i.id.equals(id))).write(
      const NoteImagesCompanion(
        isSynced: Value(true),
      ),
    );
  }

  /// Mark multiple images as synced in a single query.
  Future<void> markSyncedBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(noteImages)..where((i) => i.id.isIn(ids))).write(
      const NoteImagesCompanion(
        isSynced: Value(true),
      ),
    );
  }
}
