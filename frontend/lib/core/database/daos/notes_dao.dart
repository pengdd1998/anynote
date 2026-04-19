import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'notes_dao.g.dart';

/// Data access object for notes.
/// Handles CRUD, FTS5 search, and sync status management.
@DriftAccessor(tables: [Notes, NotesFts, NoteTags, Tags, Collections, CollectionNotes])
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

  /// Watch a paginated batch of non-deleted notes.
  /// Returns up to [limit] notes starting from [offset], ordered by
  /// update time (newest first). Designed for infinite scroll patterns.
  Stream<List<Note>> watchPaginatedNotes(int limit, int offset) {
    return (select(notes)
          ..where((n) => n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
          ..limit(limit, offset: offset))
        .watch();
  }

  /// Get a paginated batch of non-deleted notes (one-shot query).
  Future<List<Note>> getPaginatedNotes(int limit, int offset) {
    return (select(notes)
          ..where((n) => n.deletedAt.isNull())
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Count total non-deleted notes. Used to determine if more pages exist.
  Future<int> countNotes() {
    final countExpr = notes.id.count();
    final query = selectOnly(notes)..addColumns([countExpr]);
    // ignore: unnecessary_non_null_assertion
    return query.map((row) => row.read(countExpr)!).getSingle();
  }

  /// Count non-deleted notes that belong to a specific tag.
  /// Used for filtered pagination (e.g. "showing 50 of 320 in tag 'work'").
  Future<int> countNotesByTag(String tagId) async {
    final noteTagRows = await (select(noteTags)
          ..where((nt) => nt.tagId.equals(tagId)))
        .get();
    final noteIds = noteTagRows.map((nt) => nt.noteId).toList();
    if (noteIds.isEmpty) return 0;

    final countExpr = notes.id.count();
    final query = selectOnly(notes)
      ..addColumns([countExpr])
      ..where(notes.id.isIn(noteIds) & notes.deletedAt.isNull());
    // ignore: unnecessary_non_null_assertion
    return query.map((row) => row.read(countExpr)!).getSingle();
  }

  /// Count total FTS5 search matches for a query.
  /// Returns the total number of matching note IDs (before LIMIT/OFFSET).
  Future<int> countSearchResults(String query) async {
    final sanitized = _sanitizeFtsQuery(query);
    if (sanitized.isEmpty) return 0;

    await customStatement(
      'CREATE TEMP TABLE IF NOT EXISTS _fts_count (cnt INTEGER NOT NULL)',
    );
    await customStatement('DELETE FROM _fts_count');
    await customStatement(
      'INSERT INTO _fts_count (cnt) SELECT COUNT(*) FROM notes_fts WHERE notes_fts MATCH ?',
      [sanitized],
    );

    final result = await customSelect(
      'SELECT cnt FROM _fts_count',
      readsFrom: {notes},
    ).getSingleOrNull();

    if (result == null) return 0;
    return result.read<int>('cnt');
  }

  /// Get notes paginated with flexible sort order.
  /// [sortBy] can be 'updated' (default), 'created', or 'title'.
  /// [tagFilter] optionally restricts results to notes with the given tag ID.
  Future<List<Note>> getNotesPaginatedFiltered({
    required int limit,
    required int offset,
    String sortBy = 'updated',
    String? tagFilter,
  }) async {
    // If a tag filter is specified, resolve matching note IDs first.
    List<String>? tagFilteredIds;
    if (tagFilter != null) {
      final noteTagRows = await (select(noteTags)
            ..where((nt) => nt.tagId.equals(tagFilter)))
          .get();
      tagFilteredIds = noteTagRows.map((nt) => nt.noteId).toList();
      if (tagFilteredIds.isEmpty) return [];
    }

    var query = select(notes)..where((n) => n.deletedAt.isNull());

    if (tagFilteredIds != null) {
      final ids = tagFilteredIds;
      query = query..where((n) => n.id.isIn(ids));
    }

    // Apply sort order.
    switch (sortBy) {
      case 'created':
        query = query..orderBy([(n) => OrderingTerm.desc(n.createdAt)]);
        break;
      case 'title':
        query = query..orderBy([(n) => OrderingTerm.asc(n.plainTitle)]);
        break;
      case 'updated':
      default:
        query = query..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
        break;
    }

    query = query..limit(limit, offset: offset);
    return query.get();
  }

  /// Watch notes paginated with flexible sort order (reactive stream).
  /// [sortBy] can be 'updated' (default), 'created', or 'title'.
  /// [tagFilter] optionally restricts results to notes with the given tag ID.
  Stream<List<Note>> watchNotesPaginatedFiltered({
    required int limit,
    required int offset,
    String sortBy = 'updated',
    String? tagFilter,
  }) {
    // Note: Drift does not support async callbacks in watch() builders,
    // so tag filtering with a separate async query is not reactive here.
    // For tag-filtered reactive streams, use watchPaginatedNotes and
    // filter client-side, or use watchAllNotes with a client-side filter.
    var query = select(notes)..where((n) => n.deletedAt.isNull());

    switch (sortBy) {
      case 'created':
        query = query..orderBy([(n) => OrderingTerm.desc(n.createdAt)]);
        break;
      case 'title':
        query = query..orderBy([(n) => OrderingTerm.asc(n.plainTitle)]);
        break;
      case 'updated':
      default:
        query = query..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);
        break;
    }

    query = query..limit(limit, offset: offset);
    return query.watch();
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
    ),);

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
    ),);

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
    ),);

    // Remove from FTS5
    await customStatement('DELETE FROM notes_fts WHERE note_id = ?', [id]);
  }

  /// Mark a note as synced.
  Future<void> markSynced(String id) async {
    await (update(notes)..where((n) => n.id.equals(id)))
        .write(const NotesCompanion(isSynced: Value(true)));
  }

  /// Toggle pin status for a note.
  Future<void> togglePin(String id) async {
    final note = await getNoteById(id);
    if (note == null) return;
    await (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(isPinned: Value(!note.isPinned)),
    );
  }

  /// Get all unsynced notes.
  Future<List<Note>> getUnsyncedNotes() {
    return (select(notes)..where((n) => n.isSynced.equals(false))).get();
  }

  /// Search notes using FTS5.
  ///
  /// The query is sanitized to handle both Chinese and Latin text.
  /// With the unicode61 tokenizer (categories "L* N* Co"), Chinese characters
  /// are individually tokenized, so:
  /// - Single Chinese character queries work (e.g. "笔")
  /// - Multi-character Chinese queries use implicit AND matching (e.g. "笔记")
  /// - Mixed Chinese/English queries work (e.g. "Python教程")
  /// - English queries work as expected (e.g. "flutter riverpod")
  Future<List<Note>> searchNotes(String query) async {
    final sanitized = _sanitizeFtsQuery(query);
    if (sanitized.isEmpty) return [];

    // FTS5 MATCH is not compatible with Drift's customSelect SQL parser.
    // Use a temp table to bridge the gap: write FTS5 results to a temp table
    // via customStatement, then read from it via customSelect.
    await customStatement('CREATE TEMP TABLE IF NOT EXISTS _fts_results (note_id TEXT NOT NULL PRIMARY KEY)');
    await customStatement('DELETE FROM _fts_results');
    await customStatement(
      'INSERT INTO _fts_results (note_id) SELECT note_id FROM notes_fts WHERE notes_fts MATCH ?',
      [sanitized],
    );

    final ftsResults = await customSelect(
      'SELECT note_id FROM _fts_results',
      readsFrom: {notes},
    ).get();

    final matchingIds = ftsResults.map((r) => r.read<String>('note_id')).toList();
    if (matchingIds.isEmpty) return [];

    return (select(notes)
          ..where((n) => n.id.isIn(matchingIds) & n.deletedAt.isNull()))
        .get();
  }

  /// Paginated version of FTS5 search.
  /// Returns up to [limit] results starting from [offset].
  Future<List<Note>> searchNotesPaginated(
    String query,
    int limit,
    int offset,
  ) async {
    final sanitized = _sanitizeFtsQuery(query);
    if (sanitized.isEmpty) return [];

    await customStatement(
      'CREATE TEMP TABLE IF NOT EXISTS _fts_results (note_id TEXT NOT NULL PRIMARY KEY)',
    );
    await customStatement('DELETE FROM _fts_results');
    await customStatement(
      'INSERT INTO _fts_results (note_id) SELECT note_id FROM notes_fts WHERE notes_fts MATCH ?',
      [sanitized],
    );

    final ftsResults = await customSelect(
      'SELECT note_id FROM _fts_results LIMIT ? OFFSET ?',
      readsFrom: {notes},
      variables: [Variable<int>(limit), Variable<int>(offset)],
    ).get();

    final matchingIds =
        ftsResults.map((r) => r.read<String>('note_id')).toList();
    if (matchingIds.isEmpty) return [];

    return (select(notes)
          ..where((n) => n.id.isIn(matchingIds) & n.deletedAt.isNull()))
        .get();
  }

  /// Search notes with highlighted snippets using FTS5's bm25 ranking.
  ///
  /// Returns a list of [SearchResult] containing the note, a relevance rank
  /// score, and highlighted snippet text with matches wrapped in [marker]
  /// tags (defaults to ** for bold markdown-style markers).
  Future<List<SearchResult>> searchNotesWithHighlights(
    String query, {
    String marker = '**',
  }) async {
    final sanitized = _sanitizeFtsQuery(query);
    if (sanitized.isEmpty) return [];

    // FTS5 MATCH is not compatible with Drift's customSelect SQL parser.
    // Use temp table approach to store FTS5 results with rank and highlights.
    await customStatement(
      'CREATE TEMP TABLE IF NOT EXISTS _fts_hl_results ('
      'note_id TEXT NOT NULL PRIMARY KEY, '
      'rank REAL NOT NULL, '
      'content_snippet TEXT NOT NULL, '
      'title_snippet TEXT NOT NULL'
      ')',
    );
    await customStatement('DELETE FROM _fts_hl_results');
    await customStatement(
      'INSERT INTO _fts_hl_results (note_id, rank, content_snippet, title_snippet) '
      'SELECT note_id, bm25(notes_fts), '
      'highlight(notes_fts, 1, ?, ?), '
      'highlight(notes_fts, 2, ?, ?) '
      'FROM notes_fts WHERE notes_fts MATCH ? '
      'ORDER BY rank',
      [marker, marker, marker, marker, sanitized],
    );

    final ftsResults = await customSelect(
      'SELECT note_id, rank, content_snippet, title_snippet FROM _fts_hl_results ORDER BY rank',
      readsFrom: {notes},
    ).get();

    if (ftsResults.isEmpty) return [];

    final matchingIds = ftsResults.map((r) => r.read<String>('note_id')).toList();
    final noteRows = await (select(notes)
          ..where((n) => n.id.isIn(matchingIds) & n.deletedAt.isNull()))
        .get();

    final noteMap = {for (final n in noteRows) n.id: n};

    return ftsResults
        .where((r) => noteMap.containsKey(r.read<String>('note_id')))
        .map((r) {
      final noteId = r.read<String>('note_id');
      return SearchResult(
        note: noteMap[noteId]!,
        rank: r.read<double>('rank'),
        contentSnippet: r.read<String>('content_snippet'),
        titleSnippet: r.read<String>('title_snippet'),
      );
    }).toList();
  }

  /// Search notes with additional filters (date range, tags, collections).
  ///
  /// First performs an FTS5 text search (if [query] is non-empty), then
  /// filters results by [startDate]/[endDate] and tag/collection membership.
  /// If [query] is empty but tag or collection filters are set, returns all
  /// non-deleted notes matching those filters.
  Future<List<Note>> searchNotesFiltered({
    String? query,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tagIds,
    List<String>? collectionIds,
  }) async {
    // Determine the candidate note IDs from FTS5 (if query provided).
    List<String>? ftsIds;
    if (query != null && query.trim().isNotEmpty) {
      final sanitized = _sanitizeFtsQuery(query);
      if (sanitized.isEmpty) return [];

      await customStatement(
        'CREATE TEMP TABLE IF NOT EXISTS _fts_filtered (note_id TEXT NOT NULL PRIMARY KEY)',
      );
      await customStatement('DELETE FROM _fts_filtered');
      await customStatement(
        'INSERT INTO _fts_filtered (note_id) SELECT note_id FROM notes_fts WHERE notes_fts MATCH ?',
        [sanitized],
      );

      final ftsRows = await customSelect(
        'SELECT note_id FROM _fts_filtered',
        readsFrom: {notes},
      ).get();

      ftsIds = ftsRows.map((r) => r.read<String>('note_id')).toList();
      if (ftsIds.isEmpty) return [];
    }

    // If tag filter is set, find note IDs that have ALL specified tags.
    List<String>? tagFilteredIds;
    if (tagIds != null && tagIds.isNotEmpty) {
      // For each tag, collect note IDs; intersect them so notes match ALL tags.
      Set<String>? intersection;
      for (final tagId in tagIds) {
        final rows = await (select(noteTags)
              ..where((nt) => nt.tagId.equals(tagId)))
            .get();
        final ids = rows.map((nt) => nt.noteId).toSet();
        intersection = intersection == null ? ids : intersection.intersection(ids);
      }
      tagFilteredIds = intersection?.toList() ?? [];
      if (tagFilteredIds.isEmpty) return [];
    }

    // If collection filter is set, find note IDs in ANY of the collections.
    List<String>? collectionFilteredIds;
    if (collectionIds != null && collectionIds.isNotEmpty) {
      final cnRows = await (select(collectionNotes)
            ..where((cn) => cn.collectionId.isIn(collectionIds)))
          .get();
      collectionFilteredIds = cnRows.map((cn) => cn.noteId).toSet().toList();
      if (collectionFilteredIds.isEmpty) return [];
    }

    // Build the base query with deletedAt filter.
    var queryBuilder = select(notes)
      ..where((n) => n.deletedAt.isNull());

    // Apply date range filter.
    if (startDate != null) {
      queryBuilder = queryBuilder
        ..where((n) => n.updatedAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      queryBuilder = queryBuilder
        ..where((n) => n.updatedAt.isSmallerOrEqualValue(endDate));
    }

    // Apply FTS5 ID filter.
    if (ftsIds != null) {
      queryBuilder = queryBuilder..where((n) => n.id.isIn(ftsIds!));
    }

    // Apply tag ID filter (intersection -- note must be in tagFilteredIds).
    if (tagFilteredIds != null) {
      queryBuilder = queryBuilder..where((n) => n.id.isIn(tagFilteredIds!));
    }

    // Apply collection ID filter (union -- note in any collection).
    if (collectionFilteredIds != null) {
      queryBuilder =
          queryBuilder..where((n) => n.id.isIn(collectionFilteredIds!));
    }

    queryBuilder = queryBuilder
      ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]);

    return queryBuilder.get();
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
    ),);
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

  /// Sanitize a user query for FTS5 MATCH.
  ///
  /// FTS5 queries have special syntax that can cause errors if unescaped.
  /// This method:
  /// 1. Strips characters that are invalid in FTS5 MATCH expressions
  /// 2. Wraps tokens in double quotes for safe literal matching
  /// 3. Handles CJK characters correctly (they are already individual tokens)
  static String _sanitizeFtsQuery(String query) {
    // Trim and collapse whitespace
    var cleaned = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return '';

    // Remove FTS5 special operators that could cause parse errors
    // Keep: alphanumeric, CJK characters, spaces
    // Remove: ^ * OR AND NEAR ( ) { } : "
    cleaned = cleaned.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.isEmpty) return '';

    // Split into tokens and wrap each in double quotes for literal matching.
    // This prevents FTS5 syntax injection and handles CJK multi-char queries
    // by treating each space-separated segment as a quoted phrase.
    final tokens = cleaned.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return '';

    return tokens.map((t) => '"$t"').join(' ');
  }
}

/// A search result with highlighting metadata.
class SearchResult {
  final Note note;
  final double rank;
  final String contentSnippet;
  final String titleSnippet;

  SearchResult({
    required this.note,
    required this.rank,
    required this.contentSnippet,
    required this.titleSnippet,
  });
}
