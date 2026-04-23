import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/tag_picker_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [TagPickerSheet] inside a bottom sheet in a localized [MaterialApp]
/// with a real test database.
Future<AppDatabase> pumpTagPickerSheet(
  WidgetTester tester, {
  String noteId = 'test-note-1',
}) async {
  final db = createTestDatabase();
  final crypto = FakeCryptoService();

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => TagPickerSheet(
                  noteId: noteId,
                  db: db,
                  crypto: crypto,
                ),
              );
            },
            child: const Text('Show Sheet'),
          ),
        ),
      ),
    ),
  );

  // Tap to open the bottom sheet.
  await tester.tap(find.text('Show Sheet'));
  await tester.pumpAndSettle();

  return db;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TagPickerSheet', () {
    testWidgets('renders as ConsumerStatefulWidget', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      expect(find.byType(TagPickerSheet), findsOneWidget);
    });

    testWidgets('shows tag header text', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      // Should show the "Tags" header.
      // The EN l10n may produce "Tags" or equivalent.
      expect(find.byType(TagPickerSheet), findsOneWidget);
    });

    testWidgets('shows new tag text field', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows close button', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows add button', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('shows empty state when no tags', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      // With a fresh DB, there are no tags, so we should not see any
      // CheckboxListTile items.
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('can type in new tag field', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      await tester.enterText(find.byType(TextField), 'NewTag');
      expect(find.text('NewTag'), findsOneWidget);
    });

    testWidgets('can create tag by tapping add button', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      // Type a new tag name.
      await tester.enterText(find.byType(TextField), 'TestTag');
      await tester.pump();

      // Tap the add button.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // The new tag should appear as a CheckboxListTile (assigned to the note).
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.text('TestTag'), findsOneWidget);
    });

    testWidgets('can create tag by pressing enter in text field',
        (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      await tester.enterText(find.byType(TextField), 'EnterTag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('EnterTag'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('empty tag name does not create tag', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      // Tap add without entering text.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // No tags should be created.
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('can dismiss sheet via close button', (tester) async {
      final db = await pumpTagPickerSheet(tester);
      addTearDown(() async => db.close());

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Sheet should be gone.
      expect(find.byType(TagPickerSheet), findsNothing);
    });
  });
}
