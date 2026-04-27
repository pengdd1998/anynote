import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/import_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump the [ImportSheet] inside a localized MaterialApp with a bottom sheet
/// scaffold so the sheet renders properly.
Future<void> pumpImportSheet(
  WidgetTester tester, {
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
                    builder: (_) => const ImportSheet(),
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
  group('ImportSheet', () {
    testWidgets('renders import title', (tester) async {
      await pumpImportSheet(tester);

      expect(find.text('Import Notes'), findsOneWidget);
    });

    testWidgets('renders import options header', (tester) async {
      await pumpImportSheet(tester);

      expect(find.text('Import Options'), findsOneWidget);
    });

    testWidgets('renders import source buttons', (tester) async {
      await pumpImportSheet(tester);

      expect(find.text('Import from Markdown'), findsOneWidget);
      expect(find.text('Import from ZIP'), findsOneWidget);
      expect(find.text('Import from Obsidian Vault'), findsOneWidget);
    });

    testWidgets('renders preserve dates toggle', (tester) async {
      await pumpImportSheet(tester);

      expect(find.text('Preserve original dates'), findsOneWidget);
    });

    testWidgets('renders import tags toggle', (tester) async {
      await pumpImportSheet(tester);

      expect(find.text('Import tags'), findsOneWidget);
    });

    testWidgets('renders import properties toggle', (tester) async {
      await pumpImportSheet(tester);

      expect(find.text('Import properties'), findsOneWidget);
    });

    testWidgets('toggles preserve dates switch', (tester) async {
      await pumpImportSheet(tester);

      // Find the SwitchListTile for "Preserve original dates".
      final toggleFinder = find.widgetWithText(
        SwitchListTile,
        'Preserve original dates',
      );
      expect(toggleFinder, findsOneWidget);

      // Initial state should be ON (true).
      final initial = tester.widget<SwitchListTile>(toggleFinder);
      expect(initial.value, isTrue);

      // Tap to toggle off.
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      final updated = tester.widget<SwitchListTile>(toggleFinder);
      expect(updated.value, isFalse);
    });

    testWidgets('shows markdown icon for markdown button', (tester) async {
      await pumpImportSheet(tester);

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('shows zip icon for ZIP button', (tester) async {
      await pumpImportSheet(tester);

      expect(find.byIcon(Icons.folder_zip_outlined), findsOneWidget);
    });

    testWidgets('shows obsidian icon for Obsidian button', (tester) async {
      await pumpImportSheet(tester);

      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    });

    testWidgets('Obsidian button uses FilledButton style', (tester) async {
      await pumpImportSheet(tester);

      final finder = find.widgetWithText(
        FilledButton,
        'Import from Obsidian Vault',
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('Markdown and ZIP buttons use OutlinedButton style',
        (tester) async {
      await pumpImportSheet(tester);

      expect(
        find.widgetWithText(OutlinedButton, 'Import from Markdown'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Import from ZIP'),
        findsOneWidget,
      );
    });
  });
}
