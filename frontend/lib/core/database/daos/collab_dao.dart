import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'collab_dao.g.dart';

/// Data access object for collaboration state persistence.
/// Stores serialized CRDT document state per note for offline resume.
@DriftAccessor(tables: [CollabStates])
class CollabDao extends DatabaseAccessor<AppDatabase>
    with _$CollabDaoMixin {
  CollabDao(super.db);

  /// Load the serialized CRDT document state for a note.
  /// Returns null if no state has been persisted for this note.
  Future<CollabState?> loadState(String noteId) async {
    return (select(collabStates)..where((s) => s.noteId.equals(noteId)))
        .getSingleOrNull();
  }

  /// Save (upsert) the CRDT document state for a note.
  /// If a state already exists for [noteId], it is replaced.
  Future<void> saveState({
    required String noteId,
    required String documentState,
    required int lastVersion,
  }) async {
    await into(collabStates).insert(
      CollabStatesCompanion.insert(
        noteId: noteId,
        documentState: documentState,
        lastVersion: Value(lastVersion),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.replace,
    );
  }

  /// Delete the persisted CRDT state for a note.
  /// Called when a note is deleted or when the collab session is
  /// permanently ended.
  Future<void> deleteState(String noteId) async {
    await (delete(collabStates)..where((s) => s.noteId.equals(noteId))).go();
  }

  /// Update the last version (Lamport clock) for a note's collab state.
  Future<void> updateLastVersion(String noteId, int version) async {
    await (update(collabStates)..where((s) => s.noteId.equals(noteId))).write(
      CollabStatesCompanion(
        lastVersion: Value(version),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
