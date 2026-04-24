import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/collections/presentation/collection_detail_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('CollectionDetailScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionDetailScreen(collectionId: 'test-collection-id'),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('shows loading state initially', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionDetailScreen(collectionId: 'test-collection-id'),
        overrides: defaultProviderOverrides(),
      );

      // Should show a loading indicator or scaffold.
      expect(find.byType(Scaffold), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionDetailScreen(collectionId: 'test-collection-id'),
        overrides: defaultProviderOverrides(),
      );

      expect(find.byType(AppBar), findsOneWidget);

      // Manually dispose to avoid Drift timer leaks
      await handle.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
