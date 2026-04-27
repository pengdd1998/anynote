import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/link_management_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [LinkManagementSheet] inside a localized MaterialApp with a bottom
/// sheet scaffold so the sheet renders properly.
Future<void> pumpLinkManagementSheet(
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
                    builder: (_) => LinkManagementSheet(noteId: noteId),
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
  group('LinkManagementSheet', () {
    testWidgets('renders link management title', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      expect(find.text('Link Management'), findsOneWidget);
    });

    testWidgets('renders link icon in header', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('renders close button', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders backlinks and outbound filter chips', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      // Both filter chips should be visible and selected by default.
      final backlinksChip = find.widgetWithText(FilterChip, 'Backlinks');
      final outboundChip = find.widgetWithText(FilterChip, 'Outbound Links');

      expect(backlinksChip, findsOneWidget);
      expect(outboundChip, findsOneWidget);

      final backlinksWidget = tester.widget<FilterChip>(backlinksChip);
      final outboundWidget = tester.widget<FilterChip>(outboundChip);
      expect(backlinksWidget.selected, isTrue);
      expect(outboundWidget.selected, isTrue);
    });

    testWidgets('shows empty state when no links exist', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      expect(
        find.text('No links to display. Adjust filters to see more.'),
        findsOneWidget,
      );
    });

    testWidgets('can deselect backlinks filter chip', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      final backlinksChip = find.widgetWithText(FilterChip, 'Backlinks');
      await tester.tap(backlinksChip);
      await tester.pumpAndSettle();

      final updated = tester.widget<FilterChip>(backlinksChip);
      expect(updated.selected, isFalse);
    });

    testWidgets('can deselect outbound filter chip', (tester) async {
      await pumpLinkManagementSheet(tester, noteId: 'note-1');

      final outboundChip = find.widgetWithText(FilterChip, 'Outbound Links');
      await tester.tap(outboundChip);
      await tester.pumpAndSettle();

      final updated = tester.widget<FilterChip>(outboundChip);
      expect(updated.selected, isFalse);
    });

    testWidgets('renders backlinks when they exist', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.notesDao.createNote(
        id: 'source-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Backlink Source',
        plainContent: 'Content',
      );
      await db.notesDao.createNote(
        id: 'target-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Target Note',
        plainContent: 'Content',
      );
      await db.noteLinksDao.createLink(
        id: 'link-1',
        sourceId: 'source-1',
        targetId: 'target-1',
        linkType: 'wiki',
      );

      await pumpLinkManagementSheet(
        tester,
        noteId: 'target-1',
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      // Backlink item should be visible.
      expect(find.text('Backlink Source'), findsOneWidget);
      expect(find.text('Links to this note'), findsOneWidget);
    });

    testWidgets('renders outbound links when they exist', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.notesDao.createNote(
        id: 'source-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Source Note',
        plainContent: 'Content',
      );
      await db.notesDao.createNote(
        id: 'target-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Outbound Target',
        plainContent: 'Content',
      );
      await db.noteLinksDao.createLink(
        id: 'link-2',
        sourceId: 'source-1',
        targetId: 'target-1',
        linkType: 'wiki',
      );

      await pumpLinkManagementSheet(
        tester,
        noteId: 'source-1',
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      // Outbound link item should be visible.
      expect(find.text('Outbound Target'), findsOneWidget);
      expect(find.text('This note links to'), findsOneWidget);
    });

    testWidgets('renders delete icon button for each link', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.notesDao.createNote(
        id: 'source-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Source',
        plainContent: 'Content',
      );
      await db.notesDao.createNote(
        id: 'target-1',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Target',
        plainContent: 'Content',
      );
      await db.noteLinksDao.createLink(
        id: 'link-3',
        sourceId: 'source-1',
        targetId: 'target-1',
        linkType: 'wiki',
      );

      await pumpLinkManagementSheet(
        tester,
        noteId: 'target-1',
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });
}
