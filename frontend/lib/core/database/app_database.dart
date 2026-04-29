import 'dart:io' show File
    if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;

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
import 'daos/images_dao.dart';
import '../platform/platform_utils.dart';

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
    NoteImages,
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
    ImagesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  /// Set the SQLCipher encryption key derived from the user's master key.
  ///
  /// Call this after the crypto service is unlocked (post-login or post-app-
  /// launch). The key is a hex string produced by [CryptoService.deriveDatabaseKey].
  /// On the next database connection, the PRAGMA key will be applied.
  ///
  /// For backward compatibility, existing unencrypted databases will continue
  /// to open without a key until this method is called.
  static void setEncryptionKey(String hexKey) {
    _dbEncryptionKey = hexKey;
  }

  /// Clear the SQLCipher encryption key (e.g. on logout).
  static void clearEncryptionKey() {
    _dbEncryptionKey = null;
  }

  @override
  int get schemaVersion => 17;

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

/// Optional SQLCipher encryption key (hex-encoded 32-byte key).
///
/// Set by [AppDatabase.setEncryptionKey] after the crypto service is unlocked.
/// When null, the database opens without encryption (backward-compatible with
/// existing installations). When set, PRAGMA key is issued on every connection
/// so that new installations get full-database encryption at rest.
String? _dbEncryptionKey;

/// Open database connection with optional SQLCipher encryption.
///
/// On native platforms, creates a [NativeDatabase] with a [setup] callback
/// that issues PRAGMA key when an encryption key has been provided.
/// On web, delegates to [drift_flutter.driftDatabase] (SQLCipher is not
/// available in the browser; reliance on origin isolation and E2E encryption
/// of synced content provides the security boundary instead).
QueryExecutor _openConnection() {
  // Web: no native SQLite, so use the drift_flutter default (IndexedDB/OPFS).
  // SQLCipher PRAGMA is not applicable on web.
  if (kIsWeb) {
    return drift_flutter.driftDatabase(name: 'anynote.db');
  }

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'anynote.db.sqlite'));

    if (PlatformUtils.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cacheBase = (await getTemporaryDirectory()).path;
    sqlite3_lib.sqlite3.tempDirectory = cacheBase;

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        if (_dbEncryptionKey != null) {
          db.execute('PRAGMA key = "$_dbEncryptionKey"');
        }
      },
    );
  });
}
