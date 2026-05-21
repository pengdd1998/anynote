import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/widgets/error_state_widget.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

import 'test_helper.dart';

/// Finds a FilledButton by its text label.
Finder _findFilledButtonByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is FilledButton &&
        widget.child is Row &&
        (widget.child as Row).children.any(
          (child) => child is Text && child.data == label,
        ),
  );
}

/// Finds an IconButton by its icon.
Finder _findIconButtonByIcon(IconData icon) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is IconButton &&
        widget.icon is Icon &&
        (widget.icon as Icon).icon == icon,
  );
}

void main() {
  initIntegrationTest();

  group('Compose flow integration tests', () {
    late TestAppHandle handle;
    late FakeCryptoService fakeCrypto;
    late AppDatabase db;
    late SequentialFakeAIRepository aiRepo;

    setUp(() async {
      fakeCrypto = FakeCryptoService();
      db = createTestDatabase();
      aiRepo = SequentialFakeAIRepository([
        kClusterJsonResponse,
        kOutlineJsonResponse,
      ]);
    });

    tearDown(() async {
      await handle.dispose();
    });

    /// Pump the app already authenticated, starting at /notes.
    Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
      handle = await pumpTestApp(
        tester,
        overrides: composeTestOverrides(
          cryptoService: fakeCrypto,
          db: db,
          aiRepo: aiRepo,
        ),
      );

      handle.container.read(authStateProvider.notifier).state = true;
      globalContainer.read(authStateProvider.notifier).state = true;

      final context = tester.element(find.byType(Scaffold).first);
      context.go('/notes');
      await settleAndWait(tester);
    }

    /// Navigate to the Compose tab.
    Future<void> navigateToCompose(WidgetTester tester) async {
      await tapComposeTab(tester);
      await settleAndWait(tester);
    }

    /// Tap the "Start Composing" hero card button to open the note selector.
    Future<void> openNoteSelector(WidgetTester tester) async {
      final buttons = find.byType(FilledButton);
      expect(buttons, findsWidgets);
      await tester.tap(buttons.first);
      await tester.pumpAndSettle();
    }

    // ─── Test: A4-A9 Full pipeline happy path ─────────────────────────

    testWidgets(
      'A4-A9: full compose pipeline — select notes through save',
      (tester) async {
        await pumpAuthenticatedApp(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Pre-populate test notes.
        await createTestNote(
          db,
          fakeCrypto,
          'Flutter Basics',
          'Learn Flutter step by step.',
        );
        await createTestNote(
          db,
          fakeCrypto,
          'Dart Tips',
          'Useful Dart language tips.',
        );

        // Navigate to Compose tab.
        await navigateToCompose(tester);

        // Verify hero card.
        expect(find.text(l10n.aiPoweredWriting), findsOneWidget);
        expect(find.text(l10n.noCompositionsYet), findsOneWidget);

        // Open note selector.
        await openNoteSelector(tester);

        // Verify bottom sheet opened.
        expect(find.text(l10n.newComposition), findsOneWidget);

        // Enter topic.
        final topicField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == l10n.topicOrTheme,
        );
        expect(topicField, findsOneWidget);
        await tester.enterText(topicField, 'Flutter tutorial overview');
        await tester.pump();

        // Select the first note (CheckboxListTile).
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();

        // Tap "Start Composing" in the bottom sheet.
        final sheetButton = _findFilledButtonByLabel(l10n.startComposing);
        expect(sheetButton, findsWidgets);
        await tester.tap(sheetButton.last);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ─── Cluster screen ───────────────────────────────────────────
        expect(find.text(l10n.noteClusters), findsOneWidget);

        // Wait for clustering to complete (fake AI returns immediately).
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify the cluster card is displayed with "Main Theme".
        expect(find.text('Main Theme'), findsOneWidget);
        expect(find.text('Core Ideas'), findsOneWidget);

        // Tap "Generate Outline" button.
        final outlineButton = _findFilledButtonByLabel(l10n.generateOutline);
        expect(outlineButton, findsOneWidget);
        await tester.tap(outlineButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ─── Outline screen ───────────────────────────────────────────
        expect(find.text(l10n.outlineTitle), findsOneWidget);

        // Wait for outline generation to complete.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify outline content.
        expect(find.text('Test Composition'), findsOneWidget);
        expect(find.text('Introduction'), findsOneWidget);

        // Tap "Expand to Draft" button.
        final expandButton = _findFilledButtonByLabel(l10n.expandToDraft);
        expect(expandButton, findsOneWidget);
        await tester.tap(expandButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ─── Editor screen ────────────────────────────────────────────
        expect(find.text(l10n.editorTitle), findsOneWidget);

        // Wait for streaming to complete.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify draft content is displayed.
        expect(find.textContaining('First paragraph'), findsOneWidget);

        // Tap the save button (save icon in the app bar).
        final saveButton = _findIconButtonByIcon(Icons.save_outlined);
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify the success snackbar.
        expect(find.text(l10n.savedAsNote), findsOneWidget);
      },
    );

    // ─── Test: B10 — Empty notes shows empty state ────────────────────

    testWidgets(
      'B10: note selector with 0 notes shows empty state',
      (tester) async {
        await pumpAuthenticatedApp(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // No notes created — DB is empty.

        // Navigate to compose tab and open selector.
        await navigateToCompose(tester);
        await openNoteSelector(tester);

        // Verify empty state message.
        expect(find.text(l10n.noNotesAvailableCreate), findsOneWidget);

        // Verify "Start Composing" button in the sheet is disabled.
        final sheetButton = _findFilledButtonByLabel(l10n.startComposing);
        expect(sheetButton, findsWidgets);
        final button = tester.widget<FilledButton>(sheetButton.last);
        expect(button.onPressed, isNull);
      },
    );

    // ─── Test: C16-C17 — AI clustering failure shows error ─────────────

    testWidgets(
      'C16-C17: AI failure during clustering shows error with retry',
      (tester) async {
        await pumpAuthenticatedApp(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Create a test note.
        await createTestNote(db, fakeCrypto, 'Test Note', 'Some content.');

        // Configure AI to fail.
        aiRepo.shouldFail = true;

        // Navigate to compose, open selector, fill form, start compose.
        await navigateToCompose(tester);
        await openNoteSelector(tester);

        // Enter topic.
        final topicField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == l10n.topicOrTheme,
        );
        await tester.enterText(topicField, 'Test topic');
        await tester.pump();

        // Select a note.
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();

        // Start compose.
        final sheetButton = _findFilledButtonByLabel(l10n.startComposing);
        await tester.tap(sheetButton.last);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Should be on cluster screen.
        expect(find.text(l10n.noteClusters), findsOneWidget);

        // Wait for error state.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify error widget is shown.
        expect(find.byType(ErrorStateWidget), findsOneWidget);

        // Now allow AI to succeed and tap retry.
        aiRepo.shouldFail = false;
        await tester.tap(find.text(l10n.retry));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify clustering succeeded — cluster card appears.
        expect(find.text('Main Theme'), findsOneWidget);
      },
    );

    // ─── Test: D25 — Rapid tap guard ──────────────────────────────────

    testWidgets(
      'D25: rapid tap Start Composing opens only one sheet',
      (tester) async {
        await pumpAuthenticatedApp(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        await navigateToCompose(tester);

        // Rapidly tap the "Start Composing" button 3 times.
        final heroButton = find.byType(FilledButton).first;
        await tester.tap(heroButton);
        await tester.tap(heroButton);
        await tester.tap(heroButton);
        await tester.pumpAndSettle();

        // Verify only one bottom sheet is open.
        expect(find.text(l10n.newComposition), findsOneWidget);
      },
    );

    // ─── Test: E32 — Compose history after save ────────────────────────

    testWidgets(
      'E32: compose history list shows saved composition',
      (tester) async {
        await pumpAuthenticatedApp(tester);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Pre-populate a note for selection.
        await createTestNote(
          db,
          fakeCrypto,
          'History Test',
          'Content for history test.',
        );

        // Navigate to compose and run through happy path (abbreviated).
        await navigateToCompose(tester);

        // Verify initial empty state.
        expect(find.text(l10n.noCompositionsYet), findsOneWidget);

        // Open note selector.
        await openNoteSelector(tester);

        // Fill form.
        final topicField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == l10n.topicOrTheme,
        );
        await tester.enterText(topicField, 'History topic');
        await tester.pump();

        // Select note.
        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();

        // Start compose.
        final sheetButton = _findFilledButtonByLabel(l10n.startComposing);
        await tester.tap(sheetButton.last);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Cluster screen — wait for clusters.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Generate outline.
        final outlineButton = _findFilledButtonByLabel(l10n.generateOutline);
        await tester.tap(outlineButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Outline screen — expand to draft.
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final expandButton = _findFilledButtonByLabel(l10n.expandToDraft);
        await tester.tap(expandButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Editor screen — save.
        await tester.pumpAndSettle(const Duration(seconds: 2));
        final saveButton = _findIconButtonByIcon(Icons.save_outlined);
        await tester.tap(saveButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Navigate back to compose tab.
        final context = tester.element(find.byType(Scaffold).first);
        while (GoRouter.of(context).canPop()) {
          GoRouter.of(context).pop();
          await tester.pumpAndSettle();
        }
        context.go('/compose');
        await settleAndWait(tester);

        // Verify the composition appears in history (no longer empty).
        expect(find.text(l10n.noCompositionsYet), findsNothing);
      },
    );
  });
}
