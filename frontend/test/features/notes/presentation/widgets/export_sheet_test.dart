import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/export_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [ExportSheet] inside a localized MaterialApp with a bottom sheet
/// scaffold so the sheet renders properly.
Future<void> pumpExportSheet(
  WidgetTester tester, {
  ExportScope scope = ExportScope.allNotes,
  String? currentNoteId,
  Set<String>? selectedNoteIds,
  List<Override> overrides = const [],
}) async {
  // Clear any previous widget tree (including bottom sheets from prior tests).
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
                    builder: (_) => ExportSheet(
                      scope: scope,
                      currentNoteId: currentNoteId,
                      selectedNoteIds: selectedNoteIds,
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
  group('ExportSheet', () {
    testWidgets('renders export title', (tester) async {
      await pumpExportSheet(tester);

      expect(find.text('Export Notes'), findsOneWidget);
    });

    testWidgets('renders scope indicator for allNotes', (tester) async {
      await pumpExportSheet(tester, scope: ExportScope.allNotes);

      expect(find.text('Export All Notes'), findsOneWidget);
    });

    testWidgets('renders scope indicator for currentNote', (tester) async {
      await pumpExportSheet(
        tester,
        scope: ExportScope.currentNote,
        currentNoteId: 'note-123',
      );

      expect(find.text('Export Current Note'), findsOneWidget);
    });

    testWidgets('renders scope indicator for selectedNotes', (tester) async {
      await pumpExportSheet(
        tester,
        scope: ExportScope.selectedNotes,
        selectedNoteIds: {'id1', 'id2', 'id3'},
      );

      // "3 selected notes" from the l10n exportSelected(3)
      expect(find.textContaining('selected notes'), findsOneWidget);
    });

    testWidgets('renders frontmatter toggle', (tester) async {
      await pumpExportSheet(tester);

      expect(
        find.text('Include metadata (frontmatter)'),
        findsOneWidget,
      );
    });

    testWidgets('frontmatter toggle can be switched off', (tester) async {
      await pumpExportSheet(tester);

      final toggle = find.byType(SwitchListTile);
      expect(toggle, findsOneWidget);

      // The initial state should be ON (includeFrontmatter = true).
      final switchWidget = tester.widget<SwitchListTile>(toggle);
      expect(switchWidget.value, isTrue);

      // Tap to toggle off.
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      final updatedSwitch = tester.widget<SwitchListTile>(toggle);
      expect(updatedSwitch.value, isFalse);
    });

    testWidgets('shows organization options for allNotes scope',
        (tester) async {
      await pumpExportSheet(tester, scope: ExportScope.allNotes);

      expect(find.text('Organization'), findsOneWidget);
      expect(find.text('Flat'), findsOneWidget);
      expect(find.text('By Date'), findsOneWidget);
      expect(find.text('By Collection'), findsOneWidget);
      expect(find.text('By Tag'), findsOneWidget);
    });

    testWidgets('shows organization options for selectedNotes scope',
        (tester) async {
      await pumpExportSheet(
        tester,
        scope: ExportScope.selectedNotes,
        selectedNoteIds: {'id1'},
      );

      expect(find.text('Organization'), findsOneWidget);
    });

    testWidgets('hides organization options for currentNote scope',
        (tester) async {
      await pumpExportSheet(
        tester,
        scope: ExportScope.currentNote,
        currentNoteId: 'note-1',
      );

      // Verify the organization selector is not present in the sheet.
      expect(find.widgetWithText(ChoiceChip, 'Flat'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'By Date'), findsNothing);
    });

    testWidgets('renders export button', (tester) async {
      await pumpExportSheet(tester);

      expect(find.text('Export as ZIP archive'), findsOneWidget);
    });

    testWidgets('organization chips can be selected', (tester) async {
      await pumpExportSheet(tester, scope: ExportScope.allNotes);

      // "Flat" is selected by default.
      final flatChip = find.widgetWithText(ChoiceChip, 'Flat');
      expect(flatChip, findsOneWidget);
      final flatWidget = tester.widget<ChoiceChip>(flatChip);
      expect(flatWidget.selected, isTrue);

      // Tap "By Date" to change selection.
      final byDateChip = find.widgetWithText(ChoiceChip, 'By Date');
      await tester.tap(byDateChip);
      await tester.pumpAndSettle();

      // Now "By Date" should be selected.
      final updatedDateChip = tester.widget<ChoiceChip>(byDateChip);
      expect(updatedDateChip.selected, isTrue);

      // And "Flat" should be deselected.
      final updatedFlatChip = tester.widget<ChoiceChip>(flatChip);
      expect(updatedFlatChip.selected, isFalse);
    });

    testWidgets('shows format selector for currentNote scope', (tester) async {
      await pumpExportSheet(
        tester,
        scope: ExportScope.currentNote,
        currentNoteId: 'note-1',
      );

      expect(find.text('Markdown (.md)'), findsOneWidget);
      expect(find.text('HTML (.html)'), findsOneWidget);
      expect(find.text('Plain Text (.txt)'), findsOneWidget);
      expect(find.text('PDF Document'), findsOneWidget);
    });

    testWidgets('hides format selector for allNotes scope', (tester) async {
      await pumpExportSheet(tester, scope: ExportScope.allNotes);

      expect(find.text('Markdown (.md)'), findsNothing);
      expect(find.text('HTML (.html)'), findsNothing);
    });

    testWidgets('format chips can be selected for single note', (tester) async {
      await pumpExportSheet(
        tester,
        scope: ExportScope.currentNote,
        currentNoteId: 'note-1',
      );

      // Markdown is selected by default.
      final mdChip = find.widgetWithText(ChoiceChip, 'Markdown (.md)');
      expect(mdChip, findsOneWidget);
      final mdWidget = tester.widget<ChoiceChip>(mdChip);
      expect(mdWidget.selected, isTrue);

      // Tap HTML to change format.
      final htmlChip = find.widgetWithText(ChoiceChip, 'HTML (.html)');
      await tester.tap(htmlChip);
      await tester.pumpAndSettle();

      final updatedHtmlChip = tester.widget<ChoiceChip>(htmlChip);
      expect(updatedHtmlChip.selected, isTrue);

      final updatedMdChip = tester.widget<ChoiceChip>(mdChip);
      expect(updatedMdChip.selected, isFalse);
    });
  });
}
