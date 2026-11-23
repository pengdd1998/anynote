import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;

// Native database helpers: conditionally replaced with stub on web.
import 'database_native.dart'
    if (dart.library.js) 'database_native_stub.dart';

import 'tables.dart';
import 'post_template_seed.dart';
import 'daos/notes_dao.dart';
import 'db_file_flags.dart';
import 'daos/tags_dao.dart';
import 'daos/collections_dao.dart';
import 'daos/generated_contents_dao.dart';
import 'daos/sync_meta_dao.dart';
import 'daos/note_versions_dao.dart';
import 'daos/templates_dao.dart';
import 'daos/sync_operations_dao.dart';
import 'daos/note_links_dao.dart';
import 'daos/note_properties_dao.dart';
import 'daos/saved_searches_dao.dart';
import 'daos/snippets_dao.dart';
import 'daos/images_dao.dart';
import 'daos/post_template_dao.dart';

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
    SavedSearches,
    Snippets,
    NoteImages,
    PostTemplates,
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
    NoteLinksDao,
    NotePropertiesDao,
    SavedSearchesDao,
    SnippetsDao,
    ImagesDao,
    PostTemplateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 23;

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
        // m.createAll() above created `notes_fts` as a *regular* table
        // (NotesFts is a plain Drift Table in the tables list). A regular
        // table silently breaks MATCH-based search — every query returns
        // nothing. Drop it and recreate as a real FTS5 virtual table.
        // _recreateFtsTable also rebuilds the index (a no-op on a fresh DB).
        await _recreateFtsTable();
        await _seedBuiltInPostTemplates();
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
        // v7 -> v8 originally created a collab_states table; the collab
        // feature was removed in v23 and the table is dropped there (v23
        // uses DROP TABLE IF EXISTS, so installs without it are fine).
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
        if (from < 17) {
          // v16 -> v17: Add note_images table for image metadata tracking.
          await m.createTable(noteImages);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_images_note_id ON note_images (note_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_note_images_is_synced ON note_images (is_synced)',
          );
        }
        if (from < 18) {
          // v17 -> v18: Ensure generated_contents table exists and add
          // performance indexes for notes and tags.
          await m.createTable(generatedContents);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_sort_order ON notes (sort_order)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_notes_updated_pinned ON notes (updated_at, is_pinned)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_tags_plain_name ON tags (plain_name)',
          );
        }
        if (from < 19) {
          await m.addColumn(notes, notes.firstImagePath);
        }
        if (from < 20) {
          // v19 -> v20: Repair `notes_fts`. On fresh installs, onCreate's
          // createAll() left notes_fts as a regular table (the earlier
          // `CREATE VIRTUAL TABLE IF NOT EXISTS` was a no-op because the
          // table already existed), so MATCH search returned no results.
          // Recreate as a real FTS5 virtual table and rebuild the index from
          // decrypted plain content.
          await _recreateFtsTable();
        }
        if (from < 21) {
          // v20 -> v21: The FTS5 tokenize directive used invalid double quotes
          // around the categories list (`categories "L* N* Co"`), which SQLite
          // rejects with "parse error in tokenize directive" — so the v20
          // _recreateFtsTable silently failed to create the virtual table,
          // and note creation threw. Recreate with the corrected directive.
          await _recreateFtsTable();
        }
        if (from < 22) {
          // v21 -> v22: Add post_templates table for the compose template
          // system and seed the three built-in templates.
          await m.createTable(postTemplates);
          await _seedBuiltInPostTemplates();
        }
        if (from < 23) {
          // v22 -> v23: Drop the collab_states table. Realtime collaboration
          // is not a product feature (personal notes app) and the collab
          // stack was removed; legacy installs may still carry the table.
          await customStatement('DROP TABLE IF EXISTS collab_states');
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
        tokenize='unicode61'
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

  /// Self-heal the search stack at startup. Idempotent and cheap; call once
  /// after opening the database.
  ///
  /// 1. A database that [DbFileGuard] just encrypted has empty FTS tables
  ///    (`sqlcipher_export` does not copy index contents) and says so through
  ///    `PRAGMA application_id`: rebuild the index and clear the flag.
  /// 2. If `notes_fts` exists but is NOT an FTS5 virtual table (BUG-1 from the
  ///    2026-11 QA report: legacy installs created it as a plain table via
  ///    `createAll()`, and the onUpgrade path never recreated it), rebuild it
  ///    as a real FTS5 table and reindex. If the rebuild itself fails (SQLite
  ///    build without the FTS5 module), fall back to recreating the plain
  ///    table so note saves keep working; search then degrades to the DAO's
  ///    LIKE fallback.
  /// 3. Backfill `plain_title` from the first content line for notes saved
  ///    by versions that never persisted a title (BUG-3), then refresh the
  ///    FTS index so title queries hit the repaired data.
  Future<void> ensureSearchHealthy() async {
    // -- 0. index emptied by the plaintext → encrypted migration ------------
    try {
      final row = await customSelect('PRAGMA application_id').getSingle();
      if (row.read<int>('application_id') == kIndexRebuildPending) {
        await rebuildFtsIndex();
        await customStatement('PRAGMA application_id = 0');
      }
    } on Exception catch (e) {
      debugPrint('[AppDatabase] index rebuild after migration failed: $e');
    }

    // -- 1. notes_fts schema check -------------------------------------
    try {
      final masterRows = await customSelect(
        "SELECT sql FROM sqlite_master WHERE name = 'notes_fts'",
      ).get();
      // An absent table is left to the schema migration: it either creates
      // it on a fresh database or drops it on purpose (pre-v23 upgrades).
      if (masterRows.isNotEmpty) {
        final sql =
            (masterRows.single.data['sql'] as String? ?? '').toLowerCase();
        if (!sql.contains('using fts5')) {
          await _recreateFtsTable();
        }
      }
    } on Exception catch (e) {
      // _recreateFtsTable threw — most plausibly a SQLite build without
      // the FTS5 module. Restore a plain table (schema-compatible with
      // _updateFts writes); search falls back to the DAO's LIKE scan.
      try {
        await customStatement('DROP TABLE IF EXISTS notes_fts');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS notes_fts (
            note_id TEXT NOT NULL PRIMARY KEY,
            content TEXT NOT NULL,
            title TEXT
          );
        ''');
        await rebuildFtsIndex();
      } on Exception catch (e2) {
        debugPrint('[AppDatabase] FTS self-heal failed: $e / $e2');
      }
    }

    // -- 2. plain_title backfill ---------------------------------------
    try {
      final rows = await customSelect(
        'SELECT id, plain_content FROM notes '
        'WHERE plain_title IS NULL AND plain_content IS NOT NULL '
        'AND deleted_at IS NULL',
      ).get();
      var backfilled = 0;
      for (final row in rows) {
        final content = row.data['plain_content'] as String? ?? '';
        final title = derivePlainTitle(content);
        if (title == null || title.isEmpty) continue;
        await customStatement(
          'UPDATE notes SET plain_title = ? WHERE id = ?',
          [title, row.data['id']],
        );
        backfilled++;
      }
      if (backfilled > 0) {
        await rebuildFtsIndex();
      }
    } on Exception catch (e) {
      debugPrint('[AppDatabase] plain_title backfill failed: $e');
    }
  }

  /// Derive a display/search title from note content: first non-empty line,
  /// markdown heading markers stripped, capped at 80 chars. Returns null for
  /// blank content. Kept in step with the editor's own title derivation.
  static String? derivePlainTitle(String plainText) {
    for (final raw in plainText.split('\n')) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
      if (line.isEmpty) continue;
      if (line.length > 80) line = line.substring(0, 80);
      return line;
    }
    return null;
  }

  /// Seed the three built-in post templates. Idempotent (INSERT OR IGNORE).
  ///
  /// The canonical wording lives in `post_template_seed.dart`
  /// ([kBuiltInPostTemplates]) so the seeder and the domain fallback
  /// constants always match.
  Future<void> _seedBuiltInPostTemplates() async {
    for (final t in kBuiltInPostTemplates) {
      await customStatement(
        'INSERT OR IGNORE INTO post_templates '
        '(id, name, description, system_prompt, structure_hint, '
        'tone_hint, is_built_in, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, 1, 0)',
        [
          t.id,
          t.name,
          t.description,
          t.systemPrompt,
          t.structureHint,
          t.toneHint,
        ],
      );
    }
  }
}

/// Open database connection.
///
/// On native platforms this opens an SQLCipher-encrypted database (key
/// managed inside database_native.dart; legacy plaintext databases are
/// migrated in place on first open). On web, delegates to
/// [drift_flutter.driftDatabase] (SQLCipher is not available in the browser;
/// reliance on origin isolation and E2E encryption of synced content
/// provides the security boundary instead).
QueryExecutor _openConnection() {
  // Web: no native SQLite, so use the drift_flutter default (IndexedDB/OPFS).
  if (kIsWeb) {
    return drift_flutter.driftDatabase(name: 'anynote.db');
  }

  // Native: use SQLite via the platform-specific helper.
  return openNativeDatabase();
}
