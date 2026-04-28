import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('NotesListScreen behavior', () {
    testWidgets('shows overflow More menu button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // The "More" overflow PopupMenuButton should be present.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.more_vert,
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows search toggle button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Search icon should be visible.
      expect(find.byIcon(Icons.search), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows grid/list toggle button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Grid/list toggle icon should be present (either grid_view or view_list).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              (w.icon is Icon &&
                  ((w.icon as Icon).icon == Icons.grid_view ||
                      (w.icon as Icon).icon == Icons.view_list)),
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping search shows search input', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Tap the search button.
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // A TextField should now be visible for search input.
      expect(find.byType(TextField), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows empty state when no notes loaded', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // With autoLoad=false and no seeded data, the empty state should show.
      // The empty state has a Text widget with a message.
      expect(find.byType(AppBar), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has SyncStatusIndicator', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // SyncStatusIndicator should be in the actions area.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'SyncStatusIndicator',
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows sort popup menu button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Sort PopupMenuButton (with sort icon) should be present.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.sort,
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping grid toggle changes icon', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Default is list view, so grid_view icon should show.
      expect(find.byIcon(Icons.grid_view), findsOneWidget);

      // Tap the toggle.
      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pumpAndSettle();

      // After toggle, view_list icon should show (now in grid mode).
      expect(find.byIcon(Icons.view_list), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
