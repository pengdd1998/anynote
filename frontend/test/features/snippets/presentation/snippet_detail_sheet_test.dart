import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/snippets/presentation/snippet_detail_sheet.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// A test Snippet instance with all fields populated.
Snippet _testSnippet({
  String title = 'Test Snippet',
  String code = 'print("hello");',
  String language = 'Dart',
  String category = 'general',
  String description = 'A test snippet',
  String tags = 'test, demo',
  int usageCount = 5,
}) {
  return Snippet(
    id: 'snip-test-1',
    title: title,
    code: code,
    language: language,
    category: category,
    description: description,
    tags: tags,
    usageCount: usageCount,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

/// Pump the [SnippetDetailSheet] inside a localized [MaterialApp] with a
/// bottom sheet scaffold so the sheet renders properly.
Future<void> pumpDetailSheet(
  WidgetTester tester, {
  required Snippet snippet,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
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
                  builder: (_) => SnippetDetailSheet(
                    snippet: snippet,
                    onEdit: onEdit ?? () {},
                    onDelete: onDelete ?? () {},
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
  group('SnippetDetailSheet', () {
    testWidgets('renders snippet title', (tester) async {
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(title: 'Hello World'),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders code in code block', (tester) async {
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(code: 'console.log("test")'),
      );

      // The SelectableText inside the code block shows the code.
      expect(find.text('console.log("test")'), findsWidgets);
    });

    testWidgets('renders copy button', (tester) async {
      await pumpDetailSheet(tester, snippet: _testSnippet());

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('renders edit button', (tester) async {
      await pumpDetailSheet(tester, snippet: _testSnippet());

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('renders delete button', (tester) async {
      await pumpDetailSheet(tester, snippet: _testSnippet());

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('renders language chip when language is set', (tester) async {
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(language: 'Dart'),
      );

      expect(find.text('Dart'), findsWidgets);
    });

    testWidgets('renders category chip when category is set', (tester) async {
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(category: 'testing'),
      );

      expect(find.text('testing'), findsWidgets);
    });

    testWidgets('tapping delete shows confirmation dialog', (tester) async {
      await pumpDetailSheet(tester, snippet: _testSnippet());

      // Tap the delete icon button.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete this snippet?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Dismiss by tapping Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('confirming delete calls onDelete callback', (tester) async {
      var deleteCalled = false;
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(),
        onDelete: () => deleteCalled = true,
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirm deletion in dialog.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
    });

    testWidgets('renders description when present', (tester) async {
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(description: 'This is a test description'),
      );

      expect(find.text('This is a test description'), findsOneWidget);
    });

    testWidgets('renders tags when present', (tester) async {
      await pumpDetailSheet(
        tester,
        snippet: _testSnippet(tags: 'alpha, beta'),
      );

      // Tags are shown as "Tags: alpha, beta" format.
      expect(find.textContaining('alpha'), findsOneWidget);
    });
  });
}
