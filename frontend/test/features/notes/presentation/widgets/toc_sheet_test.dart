import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/toc_extractor.dart';
import 'package:anynote/features/notes/presentation/widgets/toc_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [TocSheet] inside a localized MaterialApp with a bottom sheet
/// scaffold so the sheet renders properly.
Future<void> pumpTocSheet(
  WidgetTester tester, {
  List<TocEntry> entries = const [],
  ValueChanged<TocEntry>? onHeadingSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
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
                  builder: (_) => TocSheet(
                    entries: entries,
                    onHeadingSelected: onHeadingSelected ?? (_) {},
                  ),
                );
              },
              child: const Text('Open Sheet'),
            );
          },
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
  group('TocSheet', () {
    testWidgets('renders table of contents title', (tester) async {
      await pumpTocSheet(tester);

      expect(find.text('Table of Contents'), findsOneWidget);
    });

    testWidgets('renders close button', (tester) async {
      await pumpTocSheet(tester);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows empty state when no entries', (tester) async {
      await pumpTocSheet(tester);

      expect(find.text('No headings found'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_outlined), findsOneWidget);
    });

    testWidgets('renders heading text', (tester) async {
      final entries = [
        const TocEntry(
          level: 1,
          text: 'Introduction',
          id: 'toc-0',
          lineIndex: 0,
        ),
        const TocEntry(
          level: 2,
          text: 'Background',
          id: 'toc-1',
          lineIndex: 5,
        ),
      ];

      await pumpTocSheet(tester, entries: entries);

      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Background'), findsOneWidget);
    });

    testWidgets('renders heading level indicators', (tester) async {
      final entries = [
        const TocEntry(
          level: 1,
          text: 'H1 Heading',
          id: 'toc-0',
          lineIndex: 0,
        ),
        const TocEntry(
          level: 2,
          text: 'H2 Heading',
          id: 'toc-1',
          lineIndex: 3,
        ),
        const TocEntry(
          level: 3,
          text: 'H3 Heading',
          id: 'toc-2',
          lineIndex: 6,
        ),
      ];

      await pumpTocSheet(tester, entries: entries);

      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('H3'), findsOneWidget);
    });

    testWidgets('renders different leading icons per heading level',
        (tester) async {
      final entries = [
        const TocEntry(
          level: 1,
          text: 'Level One',
          id: 'toc-0',
          lineIndex: 0,
        ),
        const TocEntry(
          level: 2,
          text: 'Level Two',
          id: 'toc-1',
          lineIndex: 2,
        ),
        const TocEntry(
          level: 3,
          text: 'Level Three',
          id: 'toc-2',
          lineIndex: 4,
        ),
        const TocEntry(
          level: 4,
          text: 'Level Four',
          id: 'toc-3',
          lineIndex: 6,
        ),
      ];

      await pumpTocSheet(tester, entries: entries);

      // Level 1 uses Icons.title, level 2 uses Icons.text_fields,
      // level 3+ uses Icons.label_outlined.
      expect(find.byIcon(Icons.title), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      // Level 3 and 4 both use label_outlined.
      expect(find.byIcon(Icons.label_outlined), findsNWidgets(2));
    });

    testWidgets('tapping a heading fires onHeadingSelected', (tester) async {
      final entries = [
        const TocEntry(
          level: 1,
          text: 'Clickable Heading',
          id: 'toc-0',
          lineIndex: 0,
        ),
      ];

      TocEntry? selected;
      await pumpTocSheet(
        tester,
        entries: entries,
        onHeadingSelected: (entry) => selected = entry,
      );

      await tester.tap(find.text('Clickable Heading'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.text, 'Clickable Heading');
      expect(selected!.level, 1);
    });

    testWidgets('tapping a heading pops the sheet', (tester) async {
      final entries = [
        const TocEntry(
          level: 1,
          text: 'Pop Test',
          id: 'toc-0',
          lineIndex: 0,
        ),
      ];

      await pumpTocSheet(
        tester,
        entries: entries,
        onHeadingSelected: (_) {},
      );

      // Sheet should be visible.
      expect(find.text('Table of Contents'), findsOneWidget);

      // Tap the heading.
      await tester.tap(find.text('Pop Test'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed.
      expect(find.text('Table of Contents'), findsNothing);
    });

    testWidgets('closes via close button', (tester) async {
      await pumpTocSheet(tester);

      expect(find.text('Table of Contents'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Table of Contents'), findsNothing);
    });
  });
}
