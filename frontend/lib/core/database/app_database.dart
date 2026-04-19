import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';
import 'daos/notes_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/collections_dao.dart';
import 'daos/generated_contents_dao.dart';
import 'daos/sync_meta_dao.dart';
import 'daos/note_versions_dao.dart';
import 'daos/templates_dao.dart';
import 'daos/sync_operations_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Notes,
    Tags,
    NoteTags,
    Collections,
    CollectionNotes,
    GeneratedContents,
    NotesFts,
    NoteVersions,
    NoteTemplates,
    SyncMeta,
    SyncOperations,
  ],
  daos: [
    NotesDao,
    TagsDao,
    CollectionsDao,
    GeneratedContentsDao,
    NoteVersionsDao,
    TemplatesDao,
    SyncMetaDao,
    SyncOperationsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create FTS5 virtual table with unicode61 tokenizer configured for
        // Chinese/CJK text. The 'categories "L* N* Co"' setting includes:
        //   L* — all Letter categories (Lu, Ll, Lt, Lm, Lo) where Lo covers CJK
        //   N* — all Number categories (Nd, Nl, No)
        //   Co — Private Use (for compatibility)
        // This ensures Chinese characters are individually recognized as tokens
        // rather than being silently skipped by the default unicode61 filter.
        await customStatement('''
          CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            note_id,
            content,
            title,
            tokenize='unicode61 categories "L* N* Co"'
          );
        ''');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // v1 -> v2: Rebuild FTS5 with Chinese-aware tokenizer.
          // The old table used default tokenizer which skips CJK characters.
          await _recreateFtsTable();
        }
        if (from < 3) {
          // v2 -> v3: Add isPinned column to notes table.
          await m.addColumn(notes, notes.isPinned);
        }
        if (from < 4) {
          // v3 -> v4: Add performance indexes.
          // Use IF NOT EXISTS so this is safe even if indexes somehow already
          // exist (e.g. partial migration retry).
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON notes (deleted_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes (created_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes (updated_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_is_pinned ON notes (is_pinned)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_is_synced ON notes (is_synced)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tags_is_synced ON tags (is_synced)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_tags_tag_id ON note_tags (tag_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_tags_note_id ON note_tags (note_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_collections_is_synced ON collections (is_synced)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_collection_notes_collection_id ON collection_notes (collection_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_collection_notes_note_id ON collection_notes (note_id)',
          );
        }
        if (from < 5) {
          // v4 -> v5: Add note_versions table for version history.
          await m.createTable(noteVersions);
        }
        if (from < 6) {
          // v5 -> v6: Add note_templates table for reusable templates.
          await m.createTable(noteTemplates);
        }
        if (from < 7) {
          // v6 -> v7: Add sync_operations table for offline-first sync queue.
          await m.createTable(syncOperations);
        }
      },
    );
  }

  /// Drop and recreate the FTS5 virtual table with the current tokenizer,
  /// then rebuild the index from existing decrypted content.
  Future<void> _recreateFtsTable() async {
    await customStatement('DROP TABLE IF EXISTS notes_fts');
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
        note_id,
        content,
        title,
        tokenize='unicode61 categories "L* N* Co"'
      );
    ''');
    await rebuildFtsIndex();
  }

  /// Rebuild FTS5 index from decrypted plain content.
  Future<void> rebuildFtsIndex() async {
    await customStatement('DELETE FROM notes_fts');
    await customStatement('''
      INSERT INTO notes_fts (note_id, content, title)
      SELECT id, plain_content, plain_title
      FROM notes
      WHERE plain_content IS NOT NULL AND deleted_at IS NULL;
    ''');
  }
}

/// Open database connection with SQLCipher support.
QueryExecutor _openConnection() {
  return driftDatabase(name: 'anynote.db');
}
