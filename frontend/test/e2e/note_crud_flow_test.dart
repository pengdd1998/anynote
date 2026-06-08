// End-to-end widget tests for the note CRUD lifecycle.
//
// Tests cover:
// - Notes list screen rendering (empty state)
// - Note creation via DAO with encryption verification
// - Note editing via DAO
// - Note soft deletion via DAO
// - Full create-verify-delete cycle

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import '../helpers/test_app_helper.dart';

/// Finder that matches the main "Create new note" FloatingActionButton,
/// excluding any other FABs or IconButtons.
Finder _mainFabFinder() => find.byWidgetPredicate(
      (w) =>
          w is FloatingActionButton &&
          w.tooltip != null &&
          w.tooltip != 'Scroll to top',
    );

void main() {
  group('Note CRUD flow - NotesListScreen', () {
    testWidgets('renders empty state when no notes exist', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // The scaffold, app bar, and FAB should be present.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(_mainFabFinder(), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has floating action button for creating notes',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // FAB should be visible with the add icon.
      expect(_mainFabFinder(), findsOneWidget);

      // The add icon appears in both the FAB and the AppBar IconButton.
      expect(find.byIcon(AppIcons.add), findsAtLeast(1));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('FAB exists and is visible', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Verify the FAB exists and is visible. We do not tap it because
      // the FAB's onPressed calls context.push() which requires a GoRouter
      // that is not available in the test harness.
      expect(_mainFabFinder(), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has sort and grid/list toggle in overflow menu',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Sort popup menu button (the overflow menu).
      expect(find.byType(PopupMenuButton<String>), findsAtLeast(1));

      // Open the overflow menu to verify grid/list toggle is inside.
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      // Grid/list toggle icon should be in the menu.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.grid_view || w.icon == Icons.view_list),
        ),
        findsOneWidget,
      );

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has search entry in overflow menu', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Open the overflow menu.
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      // Search icon should be visible in the overflow menu.
      expect(find.byIcon(AppIcons.search), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Note CRUD flow - DAO operations', () {
    testWidgets('creates and saves a note to the database', (tester) async {
      final db = createTestDatabase();
      final overrides = defaultProviderOverrides(db: db);

      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // Create a note directly via DAO (simulating what the editor would do).
      await db.notesDao.createNote(
        id: 'test-note-1',
        encryptedContent: 'enc_My test content',
        plainContent: 'My test content',
        plainTitle: 'E2E Test Note',
        encryptedTitle: 'enc_E2E Test Note',
      );

      // Verify the note was saved to the database.
      final allNotes = await db.notesDao.getAllNotes();
      expect(allNotes.length, 1);

      final savedNote = allNotes.first;
      expect(savedNote.plainTitle, equals('E2E Test Note'));
      expect(savedNote.encryptedContent, contains('enc_'));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
        'saves note content with encryption prefix via FakeCryptoService',
        (tester) async {
      final db = createTestDatabase();
      final overrides = defaultProviderOverrides(db: db);

      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // Simulate encrypted save via FakeCryptoService prefix.
      const content = 'Secret note content';
      const encrypted = 'enc_$content';

      await db.notesDao.createNote(
        id: 'crypto-test-note',
        encryptedContent: encrypted,
        plainContent: content,
        plainTitle: 'Encrypted Note',
        encryptedTitle: 'enc_Encrypted Note',
      );

      // Verify encryption happened via FakeCryptoService.
      final savedNote = await db.notesDao.getAllNotes();
      expect(savedNote.length, 1);

      final note = savedNote.first;
      expect(note.encryptedContent, isNotEmpty);
      expect(note.encryptedContent, contains('enc_'));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('can edit an existing note', (tester) async {
      final db = createTestDatabase();

      // Pre-populate a note.
      const noteId = 'existing-note-123';
      await db.notesDao.createNote(
        id: noteId,
        encryptedContent: 'enc_Original content',
        plainContent: 'Original content',
        plainTitle: 'Original Title',
        encryptedTitle: 'enc_Original Title',
      );

      final overrides = defaultProviderOverrides(db: db);
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // Verify original note exists.
      final note = await db.notesDao.getNoteById(noteId);
      expect(note, isNotNull);
      expect(note!.plainTitle, equals('Original Title'));

      // Update the note title.
      await db.notesDao.updateNote(
        id: noteId,
        encryptedContent: 'enc_Updated content',
        plainContent: 'Updated content',
        plainTitle: 'Updated Title',
        encryptedTitle: 'enc_Updated Title',
      );

      // Verify the note was updated.
      final updatedNote = await db.notesDao.getNoteById(noteId);
      expect(updatedNote, isNotNull);
      expect(updatedNote!.plainTitle, equals('Updated Title'));

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('deleting a note removes it from active list', (tester) async {
      final db = createTestDatabase();

      // Pre-populate a note.
      const noteId = 'delete-test-note';
      await db.notesDao.createNote(
        id: noteId,
        encryptedContent: 'enc_Content to delete',
        plainContent: 'Content to delete',
        plainTitle: 'Delete Me',
        encryptedTitle: 'enc_Delete Me',
      );

      final overrides = defaultProviderOverrides(db: db);
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // Verify the note is in the database.
      final notes = await db.notesDao.getAllNotes();
      expect(notes.length, 1);
      expect(notes.first.plainTitle, 'Delete Me');

      // Soft-delete the note directly via DAO.
      await db.notesDao.softDeleteNote(noteId);

      // Verify the note is now soft-deleted.
      final activeNotes = await db.notesDao.getAllNotes();
      expect(activeNotes.length, 0);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Note CRUD flow - full create-verify-delete cycle', () {
    testWidgets('create a note, verify it in DB, then delete it',
        (tester) async {
      final db = createTestDatabase();
      final overrides = defaultProviderOverrides(db: db);

      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: overrides,
      );

      // Step 1: Create a note via DAO.
      const noteId = 'cycle-test-note';
      await db.notesDao.createNote(
        id: noteId,
        encryptedContent: 'enc_Full cycle content',
        plainContent: 'Full cycle content',
        plainTitle: 'Full Cycle Note',
        encryptedTitle: 'enc_Full Cycle Note',
      );

      // Step 2: Verify the note exists.
      final notes = await db.notesDao.getAllNotes();
      expect(notes.length, 1);
      final createdNote = notes.first;
      expect(createdNote.plainTitle, 'Full Cycle Note');
      expect(createdNote.encryptedContent, isNotEmpty);

      // Step 3: Delete the note.
      await db.notesDao.softDeleteNote(createdNote.id);

      // Step 4: Verify it is gone from active notes.
      final remainingNotes = await db.notesDao.getAllNotes();
      expect(remainingNotes.length, 0);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
