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

      expect(find.text('Search'), findsOneWidget);
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

    testWidgets('shows Search your notes empty state', (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      expect(find.text('Search your notes'), findsOneWidget);
      expect(
          find.text('Enter a query or use filters to find notes'),
          findsOneWidget,);
      await handle.dispose();
    });

    testWidgets('shows filter chips for date range, tags, collections',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const AdvancedSearchScreen(),
        overrides: searchOverrides(),
      );

      expect(find.text('Date Range'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Collections'), findsOneWidget);
      await handle.dispose();
    });
  });
}
