import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_icons.dart';
import 'package:anynote/features/collections/presentation/collections_list_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('CollectionsListScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionsListScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Collections title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionsListScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Collections'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows No collections yet empty state', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionsListScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('No collections yet'), findsOneWidget);
      expect(
          find.text('Group your notes into collections'), findsOneWidget,);
      await handle.dispose();
    });

    testWidgets('shows add button for creating a new collection', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionsListScreen(),
        overrides: defaultProviderOverrides(),
      );

      // The create action is the "New Collection" CTA (which carries a
      // phosphor add icon) instead of an AppBar/FAB add button. It appears
      // both in the empty state and as a persistent action button.
      expect(find.text('New Collection'), findsAtLeast(1));
      expect(find.byIcon(AppIcons.add), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows grid/list view toggle button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionsListScreen(),
        overrides: defaultProviderOverrides(),
      );

      // By default it shows grid_view icon (since _isGridView starts as false).
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      await handle.dispose();
    });
  });
}
