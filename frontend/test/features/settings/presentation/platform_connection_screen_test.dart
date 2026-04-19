import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/features/settings/presentation/platform_connection_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('PlatformConnectionScreen', () {
    List<Override> platformOverrides() => [
          ...defaultProviderOverrides(),
          platformsProvider.overrideWith(() => _FakePlatformsNotifier()),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PlatformConnectionScreen(),
        overrides: platformOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Platform Connections title in app bar',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const PlatformConnectionScreen(),
        overrides: platformOverrides(),
      );

      expect(find.text('Platform Connections'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows empty state when no platforms', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PlatformConnectionScreen(),
        overrides: platformOverrides(),
      );

      expect(find.text('No platforms available'), findsOneWidget);
      await handle.dispose();
    });
  });
}

/// Fake platforms notifier that returns an empty list.
class _FakePlatformsNotifier extends PlatformsNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];
}
