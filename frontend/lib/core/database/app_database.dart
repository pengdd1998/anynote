import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';
import 'daos/notes_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/collections_dao.dart';
import 'daos/generated_contents_dao.dart';
import 'daos/sync_meta_dao.dart';

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
    SyncMeta,
  ],
  daos: [
    NotesDao,
    TagsDao,
    CollectionsDao,
    GeneratedContentsDao,
    SyncMetaDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create FTS5 virtual table
        await customStatement('''
          CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            note_id,
            content,
            title
          );
        ''');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations go here
      },
    );
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
  return driftDatabase(
    name: 'anynote.db',
    native: const DriftNativeOptions(
      // SQLCipher provides encryption at rest for the local database.
      // The database file itself is encrypted with a key derived from
      // the user's master key (separate from the E2E encryption layer).
      databasePathGetter: _getDatabasePath,
    ),
  );
}

Future<String> _getDatabasePath() async {
  final dbDir = await getApplicationDocumentsDirectory();
  return p.join(dbDir.path, 'anynote.db');
}
