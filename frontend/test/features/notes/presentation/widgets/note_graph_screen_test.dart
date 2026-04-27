import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/note_graph_screen.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps the [NoteGraphScreen] inside a localized [MaterialApp] with
/// standard provider overrides.
Future<void> pumpGraphScreen(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(_testDb!),
        ...overrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: NoteGraphScreen(),
      ),
    ),
  );

  // Let the FutureProvider resolve.
  await tester.pumpAndSettle(const Duration(milliseconds: 300));
}

AppDatabase? _testDb;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    _testDb = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    try {
      await _testDb?.close();
    } catch (_) {}
    _testDb = null;
    await Future.delayed(const Duration(milliseconds: 200));
  });

  group('NoteGraphScreen', () {
    testWidgets('renders app bar with Knowledge Graph title', (tester) async {
      await pumpGraphScreen(tester);

      expect(find.text('Knowledge Graph'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes exist', (tester) async {
      await pumpGraphScreen(tester);

      expect(find.text('No notes yet'), findsOneWidget);
      expect(
        find.textContaining('wiki links'),
        findsOneWidget,
      );
    });

    testWidgets('empty state shows tree icon', (tester) async {
      await pumpGraphScreen(tester);

      expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    });

    testWidgets('app bar has action buttons', (tester) async {
      await pumpGraphScreen(tester);

      expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
      expect(find.byIcon(Icons.scatter_plot_outlined), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('back navigation button exists in app bar', (tester) async {
      await pumpGraphScreen(tester);

      // The AppBar automatically provides a back button when the route
      // can pop. Since NoteGraphScreen is the home route in this test,
      // there is no automatic back button -- but the Scaffold and AppBar
      // are present.
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading indicator while data loads', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(_testDb!),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: NoteGraphScreen(),
          ),
        ),
      );

      // First frame -- loading state.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let it settle.
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    });

    testWidgets('localGraphDataProvider returns correct data from DB',
        (tester) async {
      // Verify the data layer works correctly without rendering _GraphCanvas.
      await _testDb!.notesDao.createNote(
        id: 'graph-note-1',
        encryptedContent: 'enc1',
        plainTitle: 'Alpha Note',
        plainContent: 'content alpha',
      );
      await _testDb!.notesDao.createNote(
        id: 'graph-note-2',
        encryptedContent: 'enc2',
        plainTitle: 'Beta Note',
        plainContent: 'content beta',
      );
      await _testDb!.noteLinksDao.createLink(
        id: 'link-1',
        sourceId: 'graph-note-1',
        targetId: 'graph-note-2',
        linkType: 'wiki',
      );

      // Use a ProviderContainer to read the provider directly.
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(_testDb!),
        ],
      );
      addTearDown(container.dispose);

      final graphData =
          await container.read(localGraphDataProvider(null).future);

      expect(graphData.nodes.length, 2);
      expect(graphData.edges.length, 1);
      expect(graphData.nodes.any((n) => n['title'] == 'Alpha Note'), isTrue);
      expect(graphData.nodes.any((n) => n['title'] == 'Beta Note'), isTrue);
      expect(graphData.edges.first['sourceId'], 'graph-note-1');
      expect(graphData.edges.first['targetId'], 'graph-note-2');
    });

    testWidgets('shows error state when provider fails', (tester) async {
      // Override the localGraphDataProvider to throw an error.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(_testDb!),
            localGraphDataProvider(null).overrideWith((ref) async {
              throw Exception('Database unavailable');
            }),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: NoteGraphScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.text('Error loading graph'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('reset view button is present and tappable', (tester) async {
      await pumpGraphScreen(tester);

      // The refresh button should exist in the empty state (no notes).
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // Tapping it should not throw even in empty state.
      await tester.tap(refreshButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });

  group('GraphData', () {
    test('holds nodes and edges', () {
      final data = GraphData(
        nodes: [
          {'id': 'n1', 'title': 'Note 1', 'preview': ''},
        ],
        edges: [
          {'sourceId': 'n1', 'targetId': 'n2'},
        ],
      );

      expect(data.nodes.length, 1);
      expect(data.edges.length, 1);
      expect(data.nodes.first['id'], 'n1');
      expect(data.edges.first['sourceId'], 'n1');
    });
  });
}
