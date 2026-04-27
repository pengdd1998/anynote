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
import 'daos/collab_dao.dart';
import 'daos/note_links_dao.dart';
import 'daos/note_properties_dao.dart';
import 'daos/saved_searches_dao.dart';
import 'daos/snippets_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Notes,
    Tags,
    NoteTags,
    NoteLinks,
    NoteProperties,
    Collections,
    CollectionNotes,
    GeneratedContents,
    NotesFts,
    NoteVersions,
    NoteTemplates,
    SyncMeta,
    SyncOperations,
    CollabStates,
    SavedSearches,
    Snippets,
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
    CollabDao,
    NoteLinksDao,
    NotePropertiesDao,
    SavedSearchesDao,
    SnippetsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 16;

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
        if (from < 8) {
          // v7 -> v8: Add collab_states table for CRDT persistence.
          await m.createTable(collabStates);
        }
        if (from < 9) {
          // v8 -> v9: Add note_links table for wiki-style [[links]].
          await m.createTable(noteLinks);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_links_source_id ON note_links (source_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_links_target_id ON note_links (target_id)',
          );
        }
        if (from < 10) {
          // v9 -> v10: Add note_properties table for custom metadata.
          await m.createTable(noteProperties);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_properties_note_id ON note_properties (note_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_properties_key ON note_properties (key)',
          );
        }
        if (from < 11) {
          // v10 -> v11: Add saved_searches table for named search queries.
          await m.createTable(savedSearches);
        }
        if (from < 12) {
          // v11 -> v12: Add description, usage_count, updated_at columns to
          // note_templates and widen the category semantics from 'built_in'/'custom'
          // to include 'work', 'personal', 'creative'.
          await customStatement(
            'ALTER TABLE note_templates ADD COLUMN description TEXT',
          );
          await customStatement(
            'ALTER TABLE note_templates ADD COLUMN usage_count INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE note_templates ADD COLUMN updated_at INTEGER NOT NULL DEFAULT (strftime(\'%s\',\'now\'))',
          );
        }
        if (from < 13) {
          // v12 -> v13: Add color column to notes, tags, and collections tables.
          await customStatement(
            'ALTER TABLE notes ADD COLUMN color TEXT',
          );
          await customStatement(
            'ALTER TABLE tags ADD COLUMN color TEXT',
          );
          await customStatement(
            'ALTER TABLE collections ADD COLUMN color TEXT',
          );
        }
        if (from < 14) {
          // v13 -> v14: Add sortOrder column to notes for drag-and-drop reordering.
          await customStatement(
            'ALTER TABLE notes ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 15) {
          // v14 -> v15: Add snippets table for reusable code fragments.
          await m.createTable(snippets);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_snippets_language ON snippets (language)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_snippets_category ON snippets (category)',
          );
        }
        if (from < 16) {
          // v15 -> v16: Add parent_id column to tags table for tag hierarchy.
          await m.addColumn(tags, tags.parentId);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags (parent_id)',
          );
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
