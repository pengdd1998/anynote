import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'notes_dao.g.dart';

/// Data access object for notes.
/// Handles CRUD, FTS5 search, and sync status management.
@DriftAccessor(tables: [Notes, NotesFts, NoteTags])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  /// Get all non-deleted notes, ordered by update time (newest first).
  Future<List<Note>> getAllNotes() {
    return (select(notes)
          ..where((n) => n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .get();
  }

  /// Watch all non-deleted notes (reactive stream).
  Stream<List<Note>> watchAllNotes() {
    return (select(notes)
          ..where((n) => n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  /// Get a single note by ID.
  Future<Note?> getNoteById(String id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();
  }

  /// Create a new note.
  Future<String> createNote({
    required String id,
    required String encryptedContent,
    String? encryptedTitle,
    String? plainContent,
    String? plainTitle,
  }) async {
    final now = DateTime.now();
    await into(notes).insert(NotesCompanion.insert(
      id: id,
      encryptedContent: encryptedContent,
      encryptedTitle: Value(encryptedTitle),
      plainContent: Value(plainContent),
      plainTitle: Value(plainTitle),
      createdAt: now,
      updatedAt: now,
      version: const Value(0),
      isSynced: const Value(false),
    ));

    // Update FTS5 index if we have plaintext
    if (plainContent != null) {
      await _updateFts(id, plainContent, plainTitle);
    }

    return id;
  }

  /// Update an existing note.
  Future<void> updateNote({
    required String id,
    String? encryptedContent,
    String? encryptedTitle,
    String? plainContent,
    String? plainTitle,
  }) async {
    final note = await getNoteById(id);
    if (note == null) return;

    await (update(notes)..where((n) => n.id.equals(id))).write(NotesCompanion(
      encryptedContent: Value(encryptedContent ?? note.encryptedContent),
      encryptedTitle: Value(encryptedTitle ?? note.encryptedTitle),
      plainContent: Value(plainContent ?? note.plainContent),
      plainTitle: Value(plainTitle ?? note.plainTitle),
      updatedAt: Value(DateTime.now()),
      version: Value(note.version + 1),
      isSynced: const Value(false),
    ));

    // Update FTS5 if plaintext changed
    if (plainContent != null) {
      await _updateFts(id, plainContent, plainTitle);
    }
  }

  /// Soft delete a note.
  Future<void> softDeleteNote(String id) async {
    await (update(notes)..where((n) => n.id.equals(id))).write(NotesCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
      isSynced: const Value(false),
    ));

    // Remove from FTS5
    await customStatement('DELETE FROM notes_fts WHERE note_id = ?', [id]);
  }

  /// Mark a note as synced.
  Future<void> markSynced(String id) async {
    await (update(notes)..where((n) => n.id.equals(id)))
        .write(const NotesCompanion(isSynced: Value(true)));
  }

  /// Get all unsynced notes.
  Future<List<Note>> getUnsyncedNotes() {
    return (select(notes)..where((n) => n.isSynced.equals(false))).get();
  }

  /// Search notes using FTS5.
  Future<List<Note>> searchNotes(String query) async {
    // First, find matching note IDs from FTS5
    final ftsResults = await customSelect(
      'SELECT note_id FROM notes_fts WHERE notes_fts MATCH ?',
      variables: [Variable.withString(query)],
      readsFrom: {notesFts},
    ).get();

    final matchingIds = ftsResults.map((r) => r.read<String>('note_id')).toList();
    if (matchingIds.isEmpty) return [];

    // Then fetch full note records
    return (select(notes)
          ..where((n) => n.id.isIn(matchingIds) & n.deletedAt.isNull()))
        .get();
  }

  /// Get notes by tag ID.
  Future<List<Note>> getNotesByTag(String tagId) async {
    final noteTagRows = await (select(noteTags)
          ..where((nt) => nt.tagId.equals(tagId)))
        .get();

    final noteIds = noteTagRows.map((nt) => nt.noteId).toList();
    if (noteIds.isEmpty) return [];

    return (select(notes)
          ..where((n) => n.id.isIn(noteIds) & n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .get();
  }

  /// Add a tag to a note.
  Future<void> addTagToNote(String noteId, String tagId) async {
    await into(noteTags).insert(NoteTagsCompanion.insert(
      noteId: noteId,
      tagId: tagId,
    ));
  }

  /// Remove a tag from a note.
  Future<void> removeTagFromNote(String noteId, String tagId) async {
    await (delete(noteTags)
          ..where((nt) => nt.noteId.equals(noteId) & nt.tagId.equals(tagId)))
        .go();
  }

  /// Update FTS5 index for a single note.
  Future<void> _updateFts(String noteId, String content, String? title) async {
    await customStatement('DELETE FROM notes_fts WHERE note_id = ?', [noteId]);
    await customStatement(
      'INSERT INTO notes_fts (note_id, content, title) VALUES (?, ?, ?)',
      [noteId, content, title ?? ''],
    );
  }
}
