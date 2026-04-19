import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'note_versions_dao.g.dart';

/// Data access object for note version history.
/// Stores encrypted snapshots of note content on each save.
@DriftAccessor(tables: [NoteVersions])
class NoteVersionsDao extends DatabaseAccessor<AppDatabase>
    with _$NoteVersionsDaoMixin {
  NoteVersionsDao(super.db);

  /// Insert a version snapshot for a note.
  Future<String> createVersion({
    required String id,
    required String noteId,
    String? encryptedTitle,
    String? plainTitle,
    required String encryptedContent,
    String? plainContent,
    required int versionNumber,
  }) async {
    await into(noteVersions).insert(NoteVersionsCompanion.insert(
      id: id,
      noteId: noteId,
      encryptedTitle: Value(encryptedTitle),
      plainTitle: Value(plainTitle),
      encryptedContent: encryptedContent,
      plainContent: Value(plainContent),
      versionNumber: versionNumber,
    ));
    return id;
  }

  /// Get all versions for a note, ordered by version number descending (newest first).
  Future<List<NoteVersion>> getVersionsForNote(String noteId) {
    return (select(noteVersions)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)]))
        .get();
  }

  /// Watch all versions for a note (reactive stream), newest first.
  Stream<List<NoteVersion>> watchVersionsForNote(String noteId) {
    return (select(noteVersions)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)]))
        .watch();
  }

  /// Get a specific version by ID.
  Future<NoteVersion?> getVersionById(String id) {
    return (select(noteVersions)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  /// Delete versions older than the last [keepLastN] for a given note.
  /// Keeps only the most recent N versions.
  Future<void> deleteVersionsOlderThan(String noteId, int keepLastN) async {
    // Find the version number of the Nth most recent version.
    // Everything older than that gets deleted.
    final recentVersions = await (select(noteVersions)
          ..where((v) => v.noteId.equals(noteId))
          ..orderBy([(v) => OrderingTerm.desc(v.versionNumber)])
          ..limit(keepLastN))
        .get();

    if (recentVersions.length < keepLastN) return; // nothing to trim

    final cutoffVersion = recentVersions.last.versionNumber;

    await (delete(noteVersions)
          ..where((v) =>
              v.noteId.equals(noteId) & v.versionNumber.isSmallerThanValue(cutoffVersion)))
        .go();
  }

  /// Count the number of versions for a note.
  Future<int> getVersionCount(String noteId) async {
    final countExpr = noteVersions.id.count();
    final query = selectOnly(noteVersions)
      ..addColumns([countExpr])
      ..where(noteVersions.noteId.equals(noteId));
    // ignore: unnecessary_non_null_assertion
    return query.map((row) => row.read(countExpr)!).getSingle();
  }
}
