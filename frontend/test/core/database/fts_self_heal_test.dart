import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';

/// Regression tests for QA BUG-1 (2026-11): a legacy install can carry
/// `notes_fts` as a plain table (createAll() never recreated it on upgrade),
/// which made every FTS MATCH query throw and search render "no results".
/// The DAO now falls back to a LIKE scan, and AppDatabase.ensureSearchHealthy
/// rebuilds the broken index at startup.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.notesDao.getAllNotes(); // force migrations
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedNote() {
    return db.notesDao.createNote(
      id: 'note-fts-reg',
      encryptedContent: 'ZW5jcnlwdGVk',
      plainContent: 'ZEBRA-QA-42 body text',
      plainTitle: 'Zebra title',
    );
  }

  test('fts search finds a note in a healthy index', () async {
    await seedNote();
    final ids = await db.notesDao.ftsSearchNoteIds('ZEBRA-QA-42');
    expect(ids, contains('note-fts-reg'));
  });

  test('search falls back to LIKE when the FTS table is broken', () async {
    await seedNote();

    // Corrupt the schema: turn notes_fts into a plain table (what legacy
    // installs looked like on device).
    await db.customStatement('DROP TABLE IF EXISTS notes_fts');
    await db.customStatement('''
      CREATE TABLE notes_fts (
        note_id TEXT NOT NULL PRIMARY KEY,
        content TEXT NOT NULL,
        title TEXT
      );
    ''');

    final ids = await db.notesDao.ftsSearchNoteIds('ZEBRA-QA-42');
    expect(ids, contains('note-fts-reg'),
        reason: 'LIKE fallback must keep search working on a broken index');
  });

  test('ensureSearchHealthy rebuilds a plain-table notes_fts into FTS5',
      () async {
    await seedNote();
    await db.customStatement('DROP TABLE IF EXISTS notes_fts');
    await db.customStatement('''
      CREATE TABLE notes_fts (
        note_id TEXT NOT NULL PRIMARY KEY,
        content TEXT NOT NULL,
        title TEXT
      );
    ''');

    await db.ensureSearchHealthy();

    final master = await db
        .customSelect("SELECT sql FROM sqlite_master WHERE name = 'notes_fts'")
        .getSingle();
    expect((master.data['sql'] as String).toLowerCase(), contains('fts5'),
        reason: 'self-heal must restore the FTS5 virtual table');

    final ids = await db.notesDao.ftsSearchNoteIds('ZEBRA-QA-42');
    expect(ids, contains('note-fts-reg'),
        reason: 'search must work again after the rebuild');
  });

  test('ensureSearchHealthy backfills plain_title from content', () async {
    // Simulate notes saved by old versions: plain_title left null.
    await db.notesDao.createNote(
      id: 'note-notitle',
      encryptedContent: 'ZW5jcnlwdGVk',
      plainContent: '## Backfilled Heading\nbody',
      plainTitle: null,
    );
    await db.customStatement(
      "UPDATE notes SET plain_title = NULL WHERE id = 'note-notitle'",
    );
    // Also drop the FTS index so the rebuild exercises the title column.
    await db.customStatement('DROP TABLE IF EXISTS notes_fts');
    await db.customStatement('''
      CREATE TABLE notes_fts (
        note_id TEXT NOT NULL PRIMARY KEY,
        content TEXT NOT NULL,
        title TEXT
      );
    ''');

    await db.ensureSearchHealthy();

    final row = await db
        .customSelect("SELECT plain_title FROM notes WHERE id = 'note-notitle'")
        .getSingle();
    expect(row.data['plain_title'], 'Backfilled Heading');
  });

  test('ensureSearchHealthy is a no-op on a healthy database', () async {
    await seedNote();
    // Must not throw and must not lose data.
    await db.ensureSearchHealthy();
    final note = await db.notesDao.getNoteById('note-fts-reg');
    expect(note, isNotNull);
  });

  test('broken FTS writes never fail the note save', () async {
    await seedNote();
    // Break the index on purpose, then update the note: _updateFts must
    // swallow the failure and the note row itself must update fine.
    await db.customStatement('DROP TABLE notes_fts');
    await db.notesDao.updateNote(
      id: 'note-fts-reg',
      plainContent: 'saved despite broken fts',
    );
    final note = await db.notesDao.getNoteById('note-fts-reg');
    expect(note!.plainContent, contains('saved despite broken fts'));
  });
}
