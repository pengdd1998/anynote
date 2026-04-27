import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/wiki_link_picker_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:anynote/main.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [WikiLinkPickerSheet] inside a localized MaterialApp with a bottom
/// sheet scaffold so the sheet renders properly.
Future<void> pumpWikiLinkPickerSheet(
  WidgetTester tester, {
  String query = '',
  String sourceNoteId = 'source-1',
  void Function(String noteId, String title)? onSelect,
  List<Override> overrides = const [],
}) async {
  // Use a taller surface so the DraggableScrollableSheet does not overflow.
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

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
                    builder: (_) => WikiLinkPickerSheet(
                      query: query,
                      sourceNoteId: sourceNoteId,
                      onSelect: onSelect ?? (_, __) {},
                    ),
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
  group('WikiLinkPickerSheet', () {
    testWidgets('renders link to note title', (tester) async {
      await pumpWikiLinkPickerSheet(tester);

      expect(find.text('Link to Note'), findsOneWidget);
    });

    testWidgets('renders search field', (tester) async {
      await pumpWikiLinkPickerSheet(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders close button', (tester) async {
      await pumpWikiLinkPickerSheet(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('populates search field with initial query', (tester) async {
      await pumpWikiLinkPickerSheet(tester, query: 'meeting');

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'meeting');
    });

    testWidgets('shows empty state when no notes match', (tester) async {
      await pumpWikiLinkPickerSheet(tester, query: 'xyznonexistent');

      // Either "No notes found" or "Start typing to search" depending on query.
      expect(
        find.text('No notes found'),
        findsOneWidget,
      );
    });

    testWidgets('shows note results when notes exist', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.notesDao.createNote(
        id: 'note-a',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Meeting Notes',
        plainContent: 'Content about meetings',
      );
      await db.notesDao.createNote(
        id: 'note-b',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Shopping List',
        plainContent: 'Buy groceries',
      );

      await pumpWikiLinkPickerSheet(
        tester,
        query: 'Meeting',
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      expect(find.text('Meeting Notes'), findsOneWidget);
      // Shopping List should not appear because it does not match "Meeting".
      expect(find.text('Shopping List'), findsNothing);
    });

    testWidgets('tapping a note fires onSelect callback', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.notesDao.createNote(
        id: 'note-c',
        encryptedTitle: '',
        encryptedContent: '',
        plainTitle: 'Select Me',
        plainContent: 'Some content',
      );

      String? selectedId;
      String? selectedTitle;

      await pumpWikiLinkPickerSheet(
        tester,
        overrides: [databaseProvider.overrideWithValue(db)],
        onSelect: (noteId, title) {
          selectedId = noteId;
          selectedTitle = title;
        },
      );

      // Tap the note tile.
      await tester.tap(find.text('Select Me'));
      await tester.pumpAndSettle();

      expect(selectedId, 'note-c');
      expect(selectedTitle, 'Select Me');
    });

    testWidgets('shows create new note button when search has no results',
        (tester) async {
      await pumpWikiLinkPickerSheet(tester, query: 'nonexistent');

      // The "Create new note" button appears when search text is non-empty
      // and there are no results.
      expect(find.text('Create new note'), findsOneWidget);
    });

    testWidgets('does not show create new note button with empty query',
        (tester) async {
      await pumpWikiLinkPickerSheet(tester, query: '');

      // With empty query, the "Create new note" button should not appear.
      expect(find.text('Create new note'), findsNothing);
    });
  });
}
