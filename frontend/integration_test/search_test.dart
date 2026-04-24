import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

import 'test_helper.dart';

void main() {
  initIntegrationTest();

  group('Search flow', () {
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

    /// Helper: pump the app already authenticated at /notes.
    Future<void> pumpAuthenticatedApp(WidgetTester tester) async {
      handle = await pumpTestApp(
        tester,
        overrides: defaultIntegrationOverrides(
          cryptoService: fakeCrypto,
          apiClient: fakeApi,
          db: db,
        ),
      );

      handle.container.read(authStateProvider.notifier).state = true;
      globalContainer.read(authStateProvider.notifier).state = true;

      final context = tester.element(find.byType(Scaffold).first);
      context.go('/notes');
      await settleAndWait(tester);
    }

    testWidgets(
      'search for a note by title returns the matching note',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        // Pre-populate notes in the database.
        await createTestNote(
          db,
          fakeCrypto,
          'Flutter Architecture Guide',
          'A comprehensive guide to Flutter app architecture with Riverpod.',
        );
        await createTestNote(
          db,
          fakeCrypto,
          'Go Backend Design',
          'Designing scalable Go microservices with PostgreSQL.',
        );
        await createTestNote(
          db,
          fakeCrypto,
          'E2E Encryption Overview',
          'End-to-end encryption using XChaCha20-Poly1305.',
        );

        // Reload the notes list to pick up the new notes.
        final context = tester.element(find.byType(Scaffold).first);
        context.go('/settings');
        await settleAndWait(tester);
        context.go('/notes');
        await settleAndWait(tester);

        // Tap the search icon to enter search mode.
        await tester.tap(searchToggleFinder);
        await tester.pumpAndSettle();

        // Verify the search text field is visible.
        final searchField = find.byType(TextField).first;
        expect(searchField, findsOneWidget);

        // Type the search query. The search uses FTS5 with debouncing
        // (300ms). We enter text and wait for the debounce.
        await tester.enterText(searchField, 'Flutter');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify that the matching note appears in search results.
        // The search should find "Flutter Architecture Guide".
        expect(find.text('Flutter Architecture Guide'), findsOneWidget);

        // Verify the non-matching notes do NOT appear.
        expect(find.text('Go Backend Design'), findsNothing);
        expect(find.text('E2E Encryption Overview'), findsNothing);
      },
    );

    testWidgets(
      'search for a note by content returns the matching note',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        // Pre-populate notes.
        await createTestNote(
          db,
          fakeCrypto,
          'Meeting Notes',
          'Discussed the quarterly roadmap and OKRs.',
        );
        await createTestNote(
          db,
          fakeCrypto,
          'Weekly Standup',
          'Synced on sprint progress and blockers.',
        );

        // Reload.
        final context = tester.element(find.byType(Scaffold).first);
        context.go('/settings');
        await settleAndWait(tester);
        context.go('/notes');
        await settleAndWait(tester);

        // Enter search mode.
        await tester.tap(searchToggleFinder);
        await tester.pumpAndSettle();

        // Search for content that only appears in one note.
        await tester.enterText(find.byType(TextField).first, 'quarterly');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify the matching note is shown.
        expect(find.text('Meeting Notes'), findsOneWidget);

        // Verify the non-matching note is not shown.
        expect(find.text('Weekly Standup'), findsNothing);
      },
    );

    testWidgets(
      'search with no results shows empty state',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Pre-populate a single note.
        await createTestNote(
          db,
          fakeCrypto,
          'Existing Note',
          'Some content here.',
        );

        // Reload.
        final context = tester.element(find.byType(Scaffold).first);
        context.go('/settings');
        await settleAndWait(tester);
        context.go('/notes');
        await settleAndWait(tester);

        // Enter search mode.
        await tester.tap(searchToggleFinder);
        await tester.pumpAndSettle();

        // Search for something that does not match any note.
        await tester.enterText(
          find.byType(TextField).first,
          'xyzzy_no_match_12345',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify no results empty state is shown.
        expect(find.text(l10n.noResults), findsOneWidget);
      },
    );

    testWidgets(
      'closing search returns to full note list',
      (tester) async {
        await pumpAuthenticatedApp(tester);

        // Pre-populate notes.
        await createTestNote(db, fakeCrypto, 'Note Alpha', 'Content A');
        await createTestNote(db, fakeCrypto, 'Note Beta', 'Content B');

        // Reload.
        final context = tester.element(find.byType(Scaffold).first);
        context.go('/settings');
        await settleAndWait(tester);
        context.go('/notes');
        await settleAndWait(tester);

        // Enter search mode.
        await tester.tap(searchToggleFinder);
        await tester.pumpAndSettle();

        // Type a query that filters results.
        await tester.enterText(find.byType(TextField).first, 'Alpha');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Only "Note Alpha" should be visible.
        expect(find.text('Note Alpha'), findsOneWidget);
        expect(find.text('Note Beta'), findsNothing);

        // Close search by tapping the close icon.
        await tester.tap(closeSearchFinder);
        await tester.pumpAndSettle();

        // Both notes should be visible again.
        expect(find.text('Note Alpha'), findsOneWidget);
        expect(find.text('Note Beta'), findsOneWidget);
      },
    );
  });
}
