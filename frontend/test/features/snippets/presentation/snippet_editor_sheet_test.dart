import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/snippets/presentation/snippet_editor_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// A test Snippet instance for editing tests.
Snippet _testSnippet({
  String title = 'Existing Snippet',
  String code = 'print("existing");',
  String language = 'Python',
  String category = 'scripts',
  String description = 'An existing snippet',
  String tags = 'existing, test',
}) {
  return Snippet(
    id: 'snip-edit-1',
    title: title,
    code: code,
    language: language,
    category: category,
    description: description,
    tags: tags,
    usageCount: 3,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

/// Pump the [SnippetEditorSheet] inside a localized [MaterialApp] with a
/// bottom sheet scaffold so the sheet renders properly.
Future<void> pumpEditorSheet(
  WidgetTester tester, {
  Snippet? existing,
  Future<void> Function(SnippetsCompanion companion)? onSave,
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
                  builder: (_) => SnippetEditorSheet(
                    existing: existing,
                    onSave: onSave ??
                        (_) async {
                          Navigator.pop(context);
                        },
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
  group('SnippetEditorSheet (create mode)', () {
    testWidgets('renders New Snippet title', (tester) async {
      await pumpEditorSheet(tester);

      expect(find.text('New Snippet'), findsOneWidget);
    });

    testWidgets('renders all form fields', (tester) async {
      await pumpEditorSheet(tester);

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('renders Cancel and Save buttons', (tester) async {
      await pumpEditorSheet(tester);

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Save button is disabled when title is empty', (tester) async {
      await pumpEditorSheet(tester);

      // The Save FilledButton should be disabled (onPressed is null).
      final saveButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Save button becomes enabled when title and code are filled',
        (tester) async {
      await pumpEditorSheet(tester);

      // TextFields in order: title (0), code (1), description (2), ...
      final textFields = find.byType(TextField);

      // Fill in the title.
      await tester.enterText(textFields.at(0), 'Test');
      // Fill in the code.
      await tester.enterText(textFields.at(1), 'print("hi")');
      await tester.pump();

      // Now the Save button should be enabled.
      final saveButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('tapping Cancel closes the sheet', (tester) async {
      await pumpEditorSheet(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The bottom sheet should be dismissed (only the "Open Sheet" button
      // should remain).
      expect(find.text('New Snippet'), findsNothing);
    });

    testWidgets('save invokes onSave callback with entered data',
        (tester) async {
      SnippetsCompanion? savedCompanion;
      await pumpEditorSheet(
        tester,
        onSave: (companion) async {
          savedCompanion = companion;
        },
      );

      // TextFields in order: title (0), code (1), description (2),
      // category (3), tags (4). The DropdownButtonFormField for language
      // is a separate widget type and is not counted by find.byType(TextField).
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeast(2));

      // Fill in the title field (first TextField).
      await tester.enterText(textFields.at(0), 'My Snippet');
      // Fill in the code field (second TextField).
      await tester.enterText(textFields.at(1), 'void main() {}');
      await tester.pump();

      // Tap Save.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedCompanion, isNotNull);
      expect(savedCompanion!.title.value, 'My Snippet');
    });
  });

  group('SnippetEditorSheet (edit mode)', () {
    testWidgets('renders Edit Snippet title', (tester) async {
      await pumpEditorSheet(tester, existing: _testSnippet());

      expect(find.text('Edit Snippet'), findsOneWidget);
    });

    testWidgets('pre-fills fields from existing snippet', (tester) async {
      await pumpEditorSheet(tester, existing: _testSnippet());

      // The title field should contain the existing snippet title.
      expect(find.text('Existing Snippet'), findsOneWidget);
      expect(find.text('print("existing");'), findsOneWidget);
    });
  });
}
