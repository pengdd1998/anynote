import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/collab_dao.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';

void main() {
  late AppDatabase db;
  late CollabDao collabDao;
  late NotesDao notesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    collabDao = CollabDao(db);
    notesDao = NotesDao(db);
    // Force Drift to run migrations.
    await notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  // ── Helper: create a test note ───────────────────────────

  Future<String> createNote({String id = 'note-1'}) {
    return notesDao.createNote(
      id: id,
      encryptedContent: 'enc',
    );
  }

  // ── loadState / saveState ────────────────────────────────

  group('loadState and saveState', () {
    test('loadState returns null when no state exists', () async {
      await createNote(id: 'note-ls');
      final state = await collabDao.loadState('note-ls');
      expect(state, isNull);
    });

    test('saveState inserts a new collab state', () async {
      await createNote(id: 'note-ss');
      await collabDao.saveState(
        noteId: 'note-ss',
        documentState: '{"ops":[]}',
        lastVersion: 5,
      );

      final state = await collabDao.loadState('note-ss');
      expect(state, isNotNull);
      expect(state!.noteId, 'note-ss');
      expect(state.documentState, '{"ops":[]}');
      expect(state.lastVersion, 5);
    });

    test('saveState upserts existing collab state (replace mode)', () async {
      await createNote(id: 'note-up');
      await collabDao.saveState(
        noteId: 'note-up',
        documentState: '{"ops":["v1"]}',
        lastVersion: 1,
      );
      await collabDao.saveState(
        noteId: 'note-up',
        documentState: '{"ops":["v2"]}',
        lastVersion: 2,
      );

      final state = await collabDao.loadState('note-up');
      expect(state, isNotNull);
      expect(state!.documentState, '{"ops":["v2"]}');
      expect(state.lastVersion, 2);
    });

    test('saveState sets updatedAt timestamp', () async {
      await createNote(id: 'note-ts');
      final before = DateTime.now();
      await collabDao.saveState(
        noteId: 'note-ts',
        documentState: '{}',
        lastVersion: 0,
      );
      final after = DateTime.now();

      final state = await collabDao.loadState('note-ts');
      expect(
          state!.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,);
      expect(state.updatedAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,);
    });

    test('different notes have independent states', () async {
      await createNote(id: 'note-a');
      await createNote(id: 'note-b');

      await collabDao.saveState(
        noteId: 'note-a',
        documentState: 'state-a',
        lastVersion: 10,
      );
      await collabDao.saveState(
        noteId: 'note-b',
        documentState: 'state-b',
        lastVersion: 20,
      );

      final stateA = await collabDao.loadState('note-a');
      final stateB = await collabDao.loadState('note-b');
      expect(stateA!.documentState, 'state-a');
      expect(stateB!.documentState, 'state-b');
      expect(stateA.lastVersion, 10);
      expect(stateB.lastVersion, 20);
    });
  });

  // ── deleteState ──────────────────────────────────────────

  group('deleteState', () {
    test('deletes an existing collab state', () async {
      await createNote(id: 'note-del');
      await collabDao.saveState(
        noteId: 'note-del',
        documentState: '{}',
        lastVersion: 0,
      );
      expect(await collabDao.loadState('note-del'), isNotNull);

      await collabDao.deleteState('note-del');
      expect(await collabDao.loadState('note-del'), isNull);
    });

    test('does not throw when deleting non-existent state', () async {
      await createNote(id: 'note-nostate');
      // Should complete without error.
      await collabDao.deleteState('note-nostate');
    });
  });

  // ── updateLastVersion ────────────────────────────────────

  group('updateLastVersion', () {
    test('updates the lastVersion field', () async {
      await createNote(id: 'note-ver');
      await collabDao.saveState(
        noteId: 'note-ver',
        documentState: '{}',
        lastVersion: 3,
      );

      await collabDao.updateLastVersion('note-ver', 7);

      final state = await collabDao.loadState('note-ver');
      expect(state!.lastVersion, 7);
    });

    test('does not change documentState', () async {
      await createNote(id: 'note-doc');
      await collabDao.saveState(
        noteId: 'note-doc',
        documentState: '{"preserve":true}',
        lastVersion: 0,
      );

      await collabDao.updateLastVersion('note-doc', 99);

      final state = await collabDao.loadState('note-doc');
      expect(state!.documentState, '{"preserve":true}');
    });

    test('updates updatedAt timestamp', () async {
      await createNote(id: 'note-uts');
      await collabDao.saveState(
        noteId: 'note-uts',
        documentState: '{}',
        lastVersion: 0,
      );

      final before = DateTime.now();
      await collabDao.updateLastVersion('note-uts', 1);
      final after = DateTime.now();

      final state = await collabDao.loadState('note-uts');
      expect(
          state!.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,);
      expect(state.updatedAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,);
    });
  });
}
