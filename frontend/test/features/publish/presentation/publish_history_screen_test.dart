import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/publish/data/publish_providers.dart';
import 'package:anynote/features/publish/presentation/publish_history_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('PublishHistoryScreen', () {
    List<Override> historyOverrides() => [
          ...defaultProviderOverrides(),
          publishHistoryProvider.overrideWith(() => _FakePublishHistoryNotifier()),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishHistoryScreen(),
        overrides: historyOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows filter button in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishHistoryScreen(),
        overrides: historyOverrides(),
      );

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows empty state when no history', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishHistoryScreen(),
        overrides: historyOverrides(),
      );

      // Wait for async data to resolve.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Empty state should show the publish icon.
      expect(find.byIcon(Icons.publish_outlined), findsOneWidget);
      await handle.dispose();
    });
  });
}

/// Fake publish history notifier that returns an empty list.
class _FakePublishHistoryNotifier extends PublishHistoryNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];
}
