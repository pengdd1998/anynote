import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/pressable_scale.dart';

void main() {
  group('PressableScale', () {
    /// Pumps a PressableScale wrapping a simple Text child.
    Future<void> pumpPressable(
      WidgetTester tester, {
      VoidCallback? onPressed,
      Widget? child,
      double scaleDown = 0.95,
      Duration duration = const Duration(milliseconds: 100),
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onPressed: onPressed,
              scaleDown: scaleDown,
              duration: duration,
              child: child ?? const Text('Tap me'),
            ),
          ),
        ),
      );
    }

    // -- Child rendering ----------------------------------------------

    testWidgets('renders child widget', (tester) async {
      await pumpPressable(tester);

      expect(find.text('Tap me'), findsOneWidget);
    });

    testWidgets('renders arbitrary child widget', (tester) async {
      await pumpPressable(
        tester,
        child: const Icon(Icons.star),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    // -- Callback invocation ------------------------------------------

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await pumpPressable(
        tester,
        onPressed: () => pressed = true,
      );

      await tester.tap(find.text('Tap me'));
      expect(pressed, isTrue);
    });

    testWidgets('does not crash when onPressed is null and tapped',
        (tester) async {
      await pumpPressable(
        tester,
        onPressed: null,
      );

      // Tapping with a null callback should not throw.
      await tester.tap(find.text('Tap me'));
    });

    // -- Scale animation structure ------------------------------------

    testWidgets('contains AnimatedScale widget', (tester) async {
      await pumpPressable(tester);

      expect(find.byType(AnimatedScale), findsOneWidget);
    });

    testWidgets('AnimatedScale starts at scale 1.0', (tester) async {
      await pumpPressable(tester);

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 1.0);
    });

    testWidgets('contains GestureDetector for tap handling', (tester) async {
      await pumpPressable(tester);

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    // -- Gesture-driven state changes ---------------------------------

    testWidgets('scales down on tap down', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
        duration: Duration.zero,
      );

      // Simulate a tap-down by performing a press-and-hold.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();

      // The AnimatedScale should now have the scaleDown value.
      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 0.95);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('scales back to 1.0 on tap up', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
        duration: Duration.zero,
      );

      // Press down.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();

      // Release.
      await gesture.up();
      await tester.pump();

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 1.0);
    });

    testWidgets('scales back to 1.0 on tap cancel', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
        duration: Duration.zero,
      );

      // Press down.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();

      // Cancel instead of completing the tap.
      await gesture.cancel();
      await tester.pump();

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 1.0);
    });

    // -- Custom scale factor ------------------------------------------

    testWidgets('respects custom scaleDown value', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
        scaleDown: 0.8,
        duration: Duration.zero,
      );

      // Press down to trigger the scaled state.
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.scale, 0.8);

      await gesture.up();
      await tester.pump();
    });

    // -- Animation curve and duration ---------------------------------

    testWidgets('AnimatedScale uses easeOutCubic curve', (tester) async {
      await pumpPressable(tester);

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.curve, Curves.easeOutCubic);
    });

    testWidgets('AnimatedScale uses provided duration', (tester) async {
      const customDuration = Duration(milliseconds: 200);
      await pumpPressable(
        tester,
        onPressed: () {},
        duration: customDuration,
      );

      final animatedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animatedScale.duration, customDuration);
    });

    // -- Rapid tap stability ------------------------------------------

    testWidgets('handles rapid consecutive taps without error',
        (tester) async {
      var tapCount = 0;
      await pumpPressable(
        tester,
        onPressed: () => tapCount++,
      );

      // Tap several times quickly.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Tap me'));
        await tester.pump();
      }

      expect(tapCount, 5);
    });
  });
}
