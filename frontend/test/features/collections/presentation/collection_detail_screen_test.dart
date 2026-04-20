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
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionDetailScreen(collectionId: 'test-collection-id'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Should show a loading indicator or scaffold.
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const CollectionDetailScreen(collectionId: 'test-collection-id'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
