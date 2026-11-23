import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/data/api_models.dart';
import 'package:anynote/features/settings/data/settings_providers.dart';
import 'package:anynote/features/settings/presentation/platform_connection_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('PlatformConnectionScreen', () {
    /// Overrides for a screen with nothing connected and [catalog] offered.
    List<Override> platformOverrides({
      List<PlatformCatalogEntry> catalog = const [],
    }) =>
        [
          ...defaultProviderOverrides(),
          platformsProvider.overrideWith(() => _FakePlatformsNotifier()),
          platformCatalogProvider.overrideWith((ref) async => catalog),
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

    testWidgets('shows Platform Connections title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PlatformConnectionScreen(),
        overrides: platformOverrides(),
      );

      expect(find.text('Platform Connections'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('offers every platform to connect when none is connected yet',
        (tester) async {
      // A fresh account used to see nothing here but "no platforms", which
      // left no way to connect the first one.
      final handle = await pumpScreen(
        tester,
        const PlatformConnectionScreen(),
        overrides: platformOverrides(
          catalog: const [
            PlatformCatalogEntry(
              platform: 'xiaohongshu',
              displayName: '小红书',
              connected: false,
            ),
            PlatformCatalogEntry(
              platform: 'zhihu',
              displayName: '知乎',
              connected: false,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Choose a platform to connect'), findsOneWidget);
      expect(find.text('小红书'), findsOneWidget);
      expect(find.text('知乎'), findsOneWidget);
      expect(find.text('Connect'), findsNWidgets(2));

      await handle.dispose();
    });
  });
}

/// Fake platforms notifier that returns an empty list.
class _FakePlatformsNotifier extends PlatformsNotifier {
  @override
  Future<List<PlatformConnection>> build() async => [];
}
