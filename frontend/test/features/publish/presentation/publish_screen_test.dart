import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/publish/data/publish_providers.dart';
import 'package:anynote/features/publish/presentation/publish_screen.dart';
import 'package:anynote/main.dart';
import '../../../helpers/test_app_helper.dart';

/// Fake notifier that returns an empty platform list.
class _FakeConnectedPlatformsNotifier extends ConnectedPlatformsNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];
}

/// Fake notifier that returns an empty publish history list.
class _FakePublishHistoryNotifier extends PublishHistoryNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async => [];
}

void main() {
  group('PublishScreen', () {
    List<Override> publishOverrides() => [
          ...defaultProviderOverrides(),
          connectedPlatformsProvider
              .overrideWith(() => _FakeConnectedPlatformsNotifier()),
          publishHistoryProvider
              .overrideWith(() => _FakePublishHistoryNotifier()),
          publishActionProvider.overrideWith(
            (ref) => PublishActionNotifier(ref.read(apiClientProvider)),
          ),
        ];

    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishScreen(),
        overrides: publishOverrides(),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Publish title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishScreen(),
        overrides: publishOverrides(),
      );

      // The app bar title and the publish button both say "Publish".
      expect(find.text('Publish'), findsWidgets);
      await handle.dispose();
    });

    testWidgets('shows No platforms connected when empty', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishScreen(),
        overrides: publishOverrides(),
      );

      expect(find.text('No platforms connected'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows Connect a Platform button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishScreen(),
        overrides: publishOverrides(),
      );

      expect(find.text('Connect a Platform'), findsOneWidget);
      await handle.dispose();
    });

    testWidgets('shows No publications yet when history is empty',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const PublishScreen(),
        overrides: publishOverrides(),
      );

      // Use runAsync to allow real async resolution for AsyncNotifier futures.
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      await tester.pump();

      // Scroll down to the "Recent Publications" section.
      await tester.scrollUntilVisible(
        find.text('No publications yet'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      expect(find.text('No publications yet'), findsOneWidget);
      await handle.dispose();
    });
  });
}
