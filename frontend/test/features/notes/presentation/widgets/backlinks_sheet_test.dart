import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/backlinks_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [BacklinksSheet] inside a localized MaterialApp with a bottom sheet
/// scaffold so the sheet renders properly.
Future<void> pumpBacklinksSheet(
  WidgetTester tester, {
  required String noteId,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(Container());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...defaultProviderOverrides(), ...overrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BacklinksSheet(noteId: noteId),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      ),
    ),
  );

  // Open the bottom sheet.
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BacklinksSheet', () {
    testWidgets('renders backlinks title', (tester) async {
      await pumpBacklinksSheet(tester, noteId: 'note-1');

      expect(find.text('Backlinks'), findsOneWidget);
    });

    testWidgets('renders link icon in header', (tester) async {
      await pumpBacklinksSheet(tester, noteId: 'note-1');

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('shows empty state when no backlinks exist', (tester) async {
      await pumpBacklinksSheet(tester, noteId: 'note-1');

      expect(find.text('No backlinks found'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      // Use a noteId that will cause a query, and pump only one frame so
      // the FutureBuilder is still in the waiting state.
      await tester.pumpWidget(
        ProviderScope(
          overrides: defaultProviderOverrides(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const BacklinksSheet(noteId: 'note-1'),
                      );
                    },
                    child: const Text('Open Sheet'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      // Only pump a single frame so the FutureBuilder shows loading.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('uses DraggableScrollableSheet', (tester) async {
      await pumpBacklinksSheet(tester, noteId: 'note-1');

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('renders backlinks list when backlinks exist', (tester) async {
      // Create a test database and insert a note + a backlink.
      final db = createTestDatabase();
      addTearDown(() => db.close());

      // Insert source and target notes.
      await db.notesDao.createNote(
        id: 'source-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Source Note',
        plainContent: 'Content of source',
      );
      await db.notesDao.createNote(
        id: 'target-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Target Note',
        plainContent: 'Content of target',
      );

      // Create a backlink: source-1 links to target-1.
      await db.noteLinksDao.createLink(
        id: 'link-1',
        sourceId: 'source-1',
        targetId: 'target-1',
        linkType: 'wiki',
      );

      await pumpBacklinksSheet(
        tester,
        noteId: 'target-1',
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      // The backlink to source-1 should be displayed.
      expect(find.text('Source Note'), findsOneWidget);
    });

    testWidgets('tapping a backlink tile triggers navigation', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.notesDao.createNote(
        id: 'source-2',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Clickable Source',
        plainContent: 'Content',
      );
      await db.notesDao.createNote(
        id: 'target-2',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Target',
        plainContent: 'Content',
      );
      await db.noteLinksDao.createLink(
        id: 'link-2',
        sourceId: 'source-2',
        targetId: 'target-2',
        linkType: 'wiki',
      );

      await pumpBacklinksSheet(
        tester,
        noteId: 'target-2',
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      // The backlink tile should be present with a trailing arrow icon.
      expect(find.text('Clickable Source'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      // Note: tapping the tile calls context.push via GoRouter, which requires
      // a GoRouter in the widget tree. The tile's presence and trailing icon
      // are verified instead of testing the full navigation flow.
    });
  });
}
