import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/database/daos/notes_dao.dart';
import 'package:anynote/core/database/daos/note_versions_dao.dart';

void main() {
  late AppDatabase db;
  late NoteVersionsDao versionsDao;
  late NotesDao notesDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    versionsDao = NoteVersionsDao(db);
    notesDao = NotesDao(db);
    // Force Drift to run migrations.
    await notesDao.getAllNotes();
  });

  tearDown(() async {
    await db.close();
  });

  // -- Helper: create a note + version --

  Future<void> createNoteWithVersions(
    String noteId, {
    int versionCount = 1,
  }) async {
    // Create the parent note first (required by FK constraint).
    await notesDao.createNote(
      id: noteId,
      encryptedContent: 'enc-$noteId',
      plainContent: 'Content for $noteId',
    );

    for (var i = 1; i <= versionCount; i++) {
      await versionsDao.createVersion(
        id: 'ver-$noteId-$i',
        noteId: noteId,
        encryptedContent: 'enc-v$i-$noteId',
        plainContent: 'Version $i of $noteId',
        plainTitle: i == 1 ? 'Title $noteId' : 'Title v$i $noteId',
        versionNumber: i,
      );
    }
  }

  // -- Create / Read --

  group('create and read', () {
    test('createVersion inserts a version and returns its ID', () async {
      await createNoteWithVersions('note-1');

      final versions = await versionsDao.getVersionsForNote('note-1');
      expect(versions.length, 1);
      expect(versions[0].id, 'ver-note-1-1');
      expect(versions[0].noteId, 'note-1');
      expect(versions[0].encryptedContent, 'enc-v1-note-1');
      expect(versions[0].plainContent, 'Version 1 of note-1');
      expect(versions[0].versionNumber, 1);
    });

    test('createVersion stores optional fields as null', () async {
      await notesDao.createNote(id: 'note-opt', encryptedContent: 'enc');
      await versionsDao.createVersion(
        id: 'ver-opt',
        noteId: 'note-opt',
        encryptedContent: 'enc-content',
        versionNumber: 1,
      );

      final version = await versionsDao.getVersionById('ver-opt');
      expect(version, isNotNull);
      expect(version!.encryptedTitle, isNull);
      expect(version.plainTitle, isNull);
      expect(version.plainContent, isNull);
    });

    test('createVersion with all fields populated', () async {
      await notesDao.createNote(id: 'note-full', encryptedContent: 'enc');
      await versionsDao.createVersion(
        id: 'ver-full',
        noteId: 'note-full',
        encryptedTitle: 'enc-title',
        plainTitle: 'My Title',
        encryptedContent: 'enc-content',
        plainContent: 'My Content',
        versionNumber: 3,
      );

      final version = await versionsDao.getVersionById('ver-full');
      expect(version!.encryptedTitle, 'enc-title');
      expect(version.plainTitle, 'My Title');
      expect(version.plainContent, 'My Content');
      expect(version.versionNumber, 3);
    });

    test('getVersionsForNote returns versions ordered newest first', () async {
      await createNoteWithVersions('note-ordered', versionCount: 4);

      final versions = await versionsDao.getVersionsForNote('note-ordered');
      expect(versions.length, 4);

      // Should be ordered by versionNumber descending
      expect(versions[0].versionNumber, 4);
      expect(versions[1].versionNumber, 3);
      expect(versions[2].versionNumber, 2);
      expect(versions[3].versionNumber, 1);
    });

    test('getVersionsForNote returns empty for note with no versions',
        () async {
      await notesDao.createNote(id: 'note-no-ver', encryptedContent: 'enc');

      final versions = await versionsDao.getVersionsForNote('note-no-ver');
      expect(versions, isEmpty);
    });

    test('getVersionsForNote returns empty for non-existent note', () async {
      final versions = await versionsDao.getVersionsForNote('nonexistent');
      expect(versions, isEmpty);
    });

    test('getVersionById returns null for non-existent version', () async {
      final version = await versionsDao.getVersionById('nonexistent');
      expect(version, isNull);
    });

    test('versions for different notes are isolated', () async {
      await createNoteWithVersions('note-a', versionCount: 2);
      await createNoteWithVersions('note-b', versionCount: 3);

      final versionsA = await versionsDao.getVersionsForNote('note-a');
      final versionsB = await versionsDao.getVersionsForNote('note-b');

      expect(versionsA.length, 2);
      expect(versionsB.length, 3);

      // All version noteIds should match their parent
      expect(versionsA.every((v) => v.noteId == 'note-a'), isTrue);
      expect(versionsB.every((v) => v.noteId == 'note-b'), isTrue);
    });
  });

  // -- Delete old versions --

  group('deleteVersionsOlderThan', () {
    test('keeps only the last N versions', () async {
      await createNoteWithVersions('note-trim', versionCount: 10);

      await versionsDao.deleteVersionsOlderThan('note-trim', 3);

      final remaining = await versionsDao.getVersionsForNote('note-trim');
      expect(remaining.length, 3);

      // Should keep versions 10, 9, 8 (newest first)
      expect(remaining[0].versionNumber, 10);
      expect(remaining[1].versionNumber, 9);
      expect(remaining[2].versionNumber, 8);
    });

    test('does nothing when total versions is less than keepLastN', () async {
      await createNoteWithVersions('note-few', versionCount: 3);

      await versionsDao.deleteVersionsOlderThan('note-few', 10);

      final remaining = await versionsDao.getVersionsForNote('note-few');
      expect(remaining.length, 3);
    });

    test('does nothing when total versions equals keepLastN', () async {
      await createNoteWithVersions('note-exact', versionCount: 5);

      await versionsDao.deleteVersionsOlderThan('note-exact', 5);

      final remaining = await versionsDao.getVersionsForNote('note-exact');
      expect(remaining.length, 5);
    });

    test('keeps only 1 version when keepLastN is 1', () async {
      await createNoteWithVersions('note-keep1', versionCount: 5);

      await versionsDao.deleteVersionsOlderThan('note-keep1', 1);

      final remaining = await versionsDao.getVersionsForNote('note-keep1');
      expect(remaining.length, 1);
      expect(remaining[0].versionNumber, 5);
    });

    test('does not affect versions of other notes', () async {
      await createNoteWithVersions('note-a', versionCount: 5);
      await createNoteWithVersions('note-b', versionCount: 3);

      await versionsDao.deleteVersionsOlderThan('note-a', 2);

      final remainingA = await versionsDao.getVersionsForNote('note-a');
      final remainingB = await versionsDao.getVersionsForNote('note-b');

      expect(remainingA.length, 2);
      expect(remainingB.length, 3); // Unaffected
    });
  });

  // -- Count --

  group('getVersionCount', () {
    test('returns 0 for note with no versions', () async {
      await notesDao.createNote(id: 'note-count-empty', encryptedContent: 'enc');
      expect(await versionsDao.getVersionCount('note-count-empty'), 0);
    });

    test('returns correct count after creating versions', () async {
      await createNoteWithVersions('note-count', versionCount: 7);
      expect(await versionsDao.getVersionCount('note-count'), 7);
    });

    test('returns updated count after trimming', () async {
      await createNoteWithVersions('note-count-trim', versionCount: 10);
      await versionsDao.deleteVersionsOlderThan('note-count-trim', 4);
      expect(await versionsDao.getVersionCount('note-count-trim'), 4);
    });
  });

  // -- createdAt default --

  group('createdAt timestamp', () {
    test('version has createdAt timestamp set automatically', () async {
      final before = DateTime.now();
      await createNoteWithVersions('note-ts');
      final after = DateTime.now();

      final versions = await versionsDao.getVersionsForNote('note-ts');
      expect(versions[0].createdAt.isAfter(
        before.subtract(const Duration(seconds: 1)),
      ), isTrue,);
      expect(versions[0].createdAt.isBefore(
        after.add(const Duration(seconds: 1)),
      ), isTrue,);
    });
  });

  // -- Watch --

  group('watchVersionsForNote', () {
    test('emits initial empty list for note with no versions', () async {
      await notesDao.createNote(id: 'note-watch', encryptedContent: 'enc');
      final stream = versionsDao.watchVersionsForNote('note-watch');
      final first = await stream.first;
      expect(first, isEmpty);
    });
  });
}
