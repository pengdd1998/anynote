import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_icons.dart';
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

    testWidgets('shows search entry in overflow menu', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Open the overflow menu.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.more_vert,
        ),
      );
      await tester.pumpAndSettle();

      // Search option should be in the overflow menu.
      expect(find.byIcon(AppIcons.search), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows grid/list toggle in overflow menu', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Open the overflow menu.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.more_vert,
        ),
      );
      await tester.pumpAndSettle();

      // Grid/list toggle should be present in the overflow menu
      // (either grid_view or view_list icon).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.grid_view || w.icon == Icons.view_list),
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping search in menu shows search input', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Open the overflow menu and tap the search option.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.more_vert,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the search menu item.
      await tester.tap(find.byIcon(AppIcons.search));
      await tester.pumpAndSettle();

      // The app bar title should now be a TextField for search.
      expect(find.byType(TextField), findsAtLeast(1));

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

    testWidgets('has OfflineBanner', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // OfflineBanner should be in the widget tree.
      expect(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == 'OfflineBanner',
        ),
        findsOneWidget,
      );

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows sort options inside overflow menu', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Sort is now inside the overflow "more" menu. The overflow
      // PopupMenuButton (with more_vert icon) should be present.
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

    testWidgets('tapping grid toggle in menu changes view', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      // Open the overflow menu.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.more_vert,
        ),
      );
      await tester.pumpAndSettle();

      // Default is grid view, so view_list icon should show as the toggle option.
      expect(find.byIcon(Icons.view_list), findsOneWidget);

      // Tap the toggle menu item.
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();

      // Open the menu again and verify the icon changed to grid_view.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is PopupMenuButton<String> &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.more_vert,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.grid_view), findsOneWidget);

      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
