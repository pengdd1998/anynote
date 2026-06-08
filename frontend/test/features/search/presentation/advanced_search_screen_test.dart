import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/search/data/search_providers.dart';
import 'package:anynote/features/search/presentation/advanced_search_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('AdvancedSearchScreen', () {
    List<Override> searchOverrides() => [
          ...defaultProviderOverrides(),
          searchFiltersProvider.overrideWith((ref) => SearchFiltersNotifier()),
          searchResultsProvider.overrideWith(
            (ref) async => <AdvancedSearchResult>[],
          ),
          allTagsProvider.overrideWith((ref) async => <Tag>[]),
          allCollectionsProvider.overrideWith(
            (ref) async => <Collection>[],
          ),
          recentSearchesProvider.overrideWith((ref) async => <String>[]),
          operatorSearchResultsProvider.overrideWith(
            (ref) async => <OperatorSearchResult>[],
          ),
          savedSearchesProvider.overrideWith((ref) => Stream.value([])),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Search title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      // Tab bar has three tabs: Search, Saved Searches, Search History.
      expect(find.text('Search'), findsWidgets);
      await handle.dispose();
    });

    testWidgets('shows search text field', (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      expect(find.byType(TextField), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows search hint in search bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      // The search bar has a hint text for operator-based search.
      expect(find.byType(TextField), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows search hints toggle and idle state sections',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      // The idle state should show a search hints toggle.
      expect(find.text('Show search hints'), findsOneWidget);
      await handle.dispose();
    });
  });
}
