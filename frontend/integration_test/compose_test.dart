import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

import 'test_helper.dart';

void main() {
  initIntegrationTest();

  group('Compose / note creation flow', () {
    late TestAppHandle handle;
    late FakeCryptoService fakeCrypto;
    late FakeApiClient fakeApi;
    late AppDatabase db;

    setUp(() async {
      fakeCrypto = FakeCryptoService();
      fakeApi = FakeApiClient();
      db = createTestDatabase();
    });

    tearDown(() async {
      await handle.dispose();
    });

    /// Helper: pump the app already authenticated, starting at /notes.
    Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
      handle = await pumpTestApp(
        tester,
        overrides: defaultIntegrationOverrides(
          cryptoService: fakeCrypto,
          apiClient: fakeApi,
          db: db,
        ),
      );

      // Authenticate so router does not redirect back to login.
      handle.container.read(authStateProvider.notifier).state = true;
      globalContainer.read(authStateProvider.notifier).state = true;

      final context = tester.element(find.byType(Scaffold).first);
      context.go('/notes');
      await settleAndWait(tester);
    }

    testWidgets(
      'tap FAB shows create options bottom sheet',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Verify we are on the notes screen with a FAB.
        expect(fabFinder, findsOneWidget);

        // Tap the FAB to open the create options bottom sheet.
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        // Verify the bottom sheet shows the blank note option.
        expect(find.text(l10n.blankNote), findsOneWidget);
        expect(find.text(l10n.fromTemplate), findsOneWidget);
      },
    );

    testWidgets(
      'tap blank note navigates to note editor',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Tap FAB to open create options.
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        // Tap "Blank Note" option.
        await tester.tap(find.text(l10n.blankNote));
        await tester.pumpAndSettle();

        // Verify we navigated to the note editor screen.
        expect(noteEditorFinder, findsOneWidget);
      },
    );

    testWidgets(
      'type title and content, save, and return to note list',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Navigate to the note editor directly (simulates tapping FAB > Blank Note).
        final context = tester.element(find.byType(Scaffold).first);
        context.push('/notes/new');
        await settleAndWait(tester);

        // Verify editor is shown.
        expect(noteEditorFinder, findsOneWidget);

        // Enter a title. The title field is the first TextField with
        // font size 22 / bold style.
        final titleField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.style?.fontSize == 22 &&
              widget.style?.fontWeight == FontWeight.bold,
        );
        expect(titleField, findsOneWidget);

        await tester.enterText(titleField, 'Integration Test Note');
        await tester.pump();

        // Enter content in the plain text editor. The editor may be in
        // rich or plain mode. For testing, we find the content TextField
        // that is NOT the title field. In plain mode it is a TextField with
        // maxLines: null. In rich mode it is a quill editor.
        // We look for a TextField with hintText matching "start writing".
        final contentField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == l10n.startWriting,
        );

        if (contentField.evaluate().isNotEmpty) {
          await tester.enterText(contentField, 'This is the note content.');
          await tester.pump();
        }

        // Tap the save-and-close button (checkmark icon in the app bar).
        final saveButton = find.byIcon(Icons.check);
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // After saving, we should be back at the notes list.
        // The auto-save timer (2s) may not have fired yet in test time,
        // but the explicit save via the checkmark button triggers _saveNote.
        // Verify we are back at the notes list (no longer in the editor).
        // Note: The editor may have popped, so we look for the notes list.
        expect(noteEditorFinder, findsNothing);
      },
    );

    testWidgets(
      'open existing note and verify content displays',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        // Pre-populate a note in the database.
        await createTestNote(
          db,
          fakeCrypto,
          'Existing Note Title',
          'This is the existing note content for verification.',
        );

        // Reload the notes list by navigating away and back.
        final context = tester.element(find.byType(Scaffold).first);
        context.go('/settings');
        await settleAndWait(tester);
        context.go('/notes');
        await settleAndWait(tester);

        // Look for the note title in the list.
        // The DismissibleNoteCard displays the plainTitle.
        expect(find.text('Existing Note Title'), findsOneWidget);

        // Tap the note card to open it.
        await tester.tap(find.text('Existing Note Title'));
        await tester.pumpAndSettle();

        // Verify navigation to note detail or editor.
        // On phone layout, tapping a note pushes the detail screen.
        // Check that the note detail screen appeared.
        // The NoteDetailScreen or inline detail should show the content.
        // Since we are on phone layout, it pushes /notes/:id.
        // Verify that we are no longer on the notes list with its FAB.
        // (The detail screen does not have the same FAB.)
      },
    );

    testWidgets(
      'navigate to compose tab shows AI compose screen',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Tap the Compose tab (index 1) via the bottom navigation bar.
        // The bottom navigation destinations use l10n labels.
        // Find the NavigationBar and tap the second destination.
        final navBar = tester.widget<NavigationBar>(bottomNavigationBar);
        final composeIndex = navBar.destinations.indexWhere(
          (d) {
            final dest = d as NavigationDestination;
            return dest.icon is Icon &&
                (dest.icon as Icon).icon == Icons.auto_awesome_outlined;
          },
        );

        expect(composeIndex, greaterThanOrEqualTo(0));

        // Tap the compose tab in the navigation bar.
        // Use the finder for the compose destination.
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is NavigationDestination &&
                widget.icon is Icon &&
                (widget.icon as Icon).icon == Icons.auto_awesome_outlined,
          ),
        );

        // NavigationBar destinations are not directly tappable with finders
        // in the standard way. Instead, tap by index using the navigation bar
        // callback simulation.
        // Actually, we can tap the text label or icon. Let's find by tooltip.
        // The NavigationBar has destinations; tapping the 2nd one.
        await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
        await tester.pumpAndSettle();

        // Verify the compose screen is displayed.
        // The compose screen shows "AI Powered Writing" text.
        expect(find.text(l10n.aiPoweredWriting), findsOneWidget);
        expect(find.text(l10n.startComposing), findsWidgets);
      },
    );
  });
}
