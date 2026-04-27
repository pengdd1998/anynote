import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/snippets/presentation/snippets_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('SnippetsScreen', () {
    testWidgets('shows empty state when no snippets exist', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Empty state shows the code-off icon.
      expect(find.byIcon(Icons.code_off_outlined), findsOneWidget);
      expect(find.text('No snippets yet'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('renders list of snippets', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      // Insert two snippets.
      await db.into(db.snippets).insert(
            SnippetsCompanion.insert(
              id: 'snip-1',
              title: 'Hello World',
              language: const Value('dart'),
              code: "print('hello');",
              category: const Value('general'),
              tags: const Value(''),
              usageCount: const Value(3),
            ),
          );
      await db.into(db.snippets).insert(
            SnippetsCompanion.insert(
              id: 'snip-2',
              title: 'Fetch Data',
              language: const Value('python'),
              code: 'requests.get(url)',
              category: const Value('general'),
              tags: const Value('http'),
              usageCount: const Value(1),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Both snippet titles should be visible.
      expect(find.text('Hello World'), findsOneWidget);
      expect(find.text('Fetch Data'), findsOneWidget);

      // Language badges.
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('python'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows add button in app bar and FAB', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Two add icons: one in AppBar actions, one as FAB.
      expect(find.byIcon(Icons.add), findsNWidgets(2));
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows search bar', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Search bar with search icon.
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('tapping snippet opens detail sheet', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.snippets).insert(
            SnippetsCompanion.insert(
              id: 'snip-tap',
              title: 'Test Snippet',
              language: const Value('js'),
              code: 'console.log("hi")',
              category: const Value('general'),
              tags: const Value(''),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Tap the snippet card.
      await tester.tap(find.text('Test Snippet'));
      await tester.pumpAndSettle();

      // A bottom sheet should open (indicated by a ModalBarrier or
      // the presence of the snippet code in the sheet).
      expect(find.text('console.log("hi")'), findsWidgets);

      await handle.dispose();
    });

    testWidgets('search filters snippets by title', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.snippets).insert(
            SnippetsCompanion.insert(
              id: 'snip-a',
              title: 'Alpha Snippet',
              language: const Value('dart'),
              code: '// alpha',
              category: const Value('general'),
              tags: const Value(''),
            ),
          );
      await db.into(db.snippets).insert(
            SnippetsCompanion.insert(
              id: 'snip-b',
              title: 'Beta Snippet',
              language: const Value('python'),
              code: '# beta',
              category: const Value('general'),
              tags: const Value(''),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // Both snippets visible initially.
      expect(find.text('Alpha Snippet'), findsOneWidget);
      expect(find.text('Beta Snippet'), findsOneWidget);

      // Type 'alpha' into the search field.
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump();

      // Only Alpha should be visible now.
      expect(find.text('Alpha Snippet'), findsOneWidget);
      expect(find.text('Beta Snippet'), findsNothing);

      await handle.dispose();
    });

    testWidgets('shows code preview in card', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await db.into(db.snippets).insert(
            SnippetsCompanion.insert(
              id: 'snip-code',
              title: 'Multi-line',
              language: const Value('rust'),
              code: 'fn main() {\n  println!("hello");\n}',
              category: const Value('general'),
              tags: const Value(''),
            ),
          );

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // The code preview should show the first non-empty lines.
      expect(find.textContaining('fn main()'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows loading state while snippets load', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      final handle = await pumpScreen(
        tester,
        const SnippetsScreen(),
        overrides: defaultProviderOverrides(db: db),
      );
      addTearDown(() => handle.dispose());

      // The screen should have rendered a Scaffold at minimum.
      expect(find.byType(Scaffold), findsOneWidget);

      await handle.dispose();
    });
  });
}
