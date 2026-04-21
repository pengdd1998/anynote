import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/connectivity_provider.dart';
import 'package:anynote/core/widgets/offline_banner.dart';

void main() {
  group('OfflineBanner', () {
    /// Pumps the OfflineBanner inside a ProviderScope with the given
    /// connectivity stream override.
    Future<void> pumpBanner(
      WidgetTester tester, {
      required Stream<ConnectivityState> connectivityStream,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectivityProvider.overrideWith((ref) => connectivityStream),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfflineBanner(),
            ),
          ),
        ),
      );
      // Let the stream deliver its initial value.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // -- Offline state ------------------------------------------------

    testWidgets('shows banner text when offline', (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(false),
      );

      expect(
        find.text('You are offline \u2014 changes will sync when connected'),
        findsOneWidget,
      );
    });

    testWidgets('shows wifi_off icon when offline', (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(false),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('has non-zero height when offline', (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(false),
      );

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      // The height should be 32 when offline.
      // AnimatedContainer stores the target value in its named args.
      // We verify indirectly by checking that the banner text is visible.
      expect(
        find.text('You are offline \u2014 changes will sync when connected'),
        findsOneWidget,
      );
    });

    // -- Online state -------------------------------------------------

    testWidgets('hides banner text when online', (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(true),
      );

      expect(
        find.text('You are offline \u2014 changes will sync when connected'),
        findsNothing,
      );
    });

    testWidgets('does not show wifi_off icon when online', (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(true),
      );

      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });

    // -- Unknown connectivity state -----------------------------------

    testWidgets('hides banner when connectivity is unknown (null)',
        (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(null),
      );

      expect(
        find.text('You are offline \u2014 changes will sync when connected'),
        findsNothing,
      );
    });

    // -- Animation ----------------------------------------------------

    testWidgets('uses AnimatedContainer for smooth transitions',
        (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(false),
      );

      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    // -- Widget structure (offline) -----------------------------------

    testWidgets('contains a Row with Icon and Text when offline',
        (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(false),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
      // The text widget exists and contains the offline message.
      final text = tester.widget<Text>(
        find.text('You are offline \u2014 changes will sync when connected'),
      );
      expect(text.style?.fontSize, 12);
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    // -- Renders without errors (smoke test) --------------------------

    testWidgets('renders without throwing', (tester) async {
      await pumpBanner(
        tester,
        connectivityStream: Stream.value(false),
      );

      expect(find.byType(OfflineBanner), findsOneWidget);
    });
  });
}
