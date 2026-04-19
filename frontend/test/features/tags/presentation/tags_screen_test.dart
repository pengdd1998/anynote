import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/tags/presentation/tags_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('TagsScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Tags title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('Tags'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows No tags empty state', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.text('No tags'), findsOneWidget);
      expect(find.text('Create tags to organize your notes'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows FAB for creating a new tag', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      await handle.dispose();
    });
  });
}
