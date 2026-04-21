// End-to-end smoke tests for route navigation.
//
// Verifies that all major routes can render their target screen
// without throwing errors. Each test pumps the screen directly
// (bypassing GoRouter redirects that require auth state) using
// the standard test helper pattern.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import 'package:anynote/features/settings/presentation/settings_screen.dart';
import 'package:anynote/features/tags/presentation/tags_screen.dart';
import 'package:anynote/features/search/presentation/advanced_search_screen.dart';
import 'package:anynote/features/collections/presentation/collections_list_screen.dart';
import 'package:anynote/features/share/presentation/discover_screen.dart';
import '../helpers/test_app_helper.dart';

void main() {
  group('Routing smoke - NotesListScreen (/notes)', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(NotesListScreen), findsOneWidget);

      await handle.dispose();
    });
  });

  group('Routing smoke - SettingsScreen (/settings)', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const SettingsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Pump to allow staggered animation frames to settle.
      await tester.pump(const Duration(milliseconds: 500));
      await handle.dispose();
    });
  });

  group('Routing smoke - TagsScreen (/tags)', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const TagsScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(TagsScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await handle.dispose();
    });
  });

  group('Routing smoke - AdvancedSearchScreen (/search)', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AdvancedSearchScreen), findsOneWidget);

      await handle.dispose();
    });
  });

  group('Routing smoke - CollectionsListScreen (/collections)', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionsListScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CollectionsListScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await handle.dispose();
    });
  });

  group('Routing smoke - DiscoverScreen (/discover)', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const DiscoverScreen(),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(DiscoverScreen), findsOneWidget);

      await handle.dispose();
    });
  });
}
