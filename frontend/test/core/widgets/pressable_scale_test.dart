import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/pressable_scale.dart';

void main() {
  group('PressableScale', () {
    Future<void> pumpPressable(
      WidgetTester tester, {
      VoidCallback? onPressed,
      Widget? child,
      double scaleDown = 0.95,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onPressed: onPressed,
              scaleDown: scaleDown,
              child: child ?? const Text('Tap me'),
            ),
          ),
        ),
      );
    }

    /// Finds the [Transform] that wraps the child content inside
    /// [PressableScale], avoiding ancestor [Transform]s from [MaterialApp].
    Finder findScaleTransform(WidgetTester tester) {
      final childFinder = find.text('Tap me');
      return find.ancestor(
        of: childFinder,
        matching: find.byType(Transform),
      );
    }

    /// Reads the X-axis scale factor from the [Transform] wrapping the child.
    double readScale(WidgetTester tester) {
      final transform =
          tester.widget<Transform>(findScaleTransform(tester).first);
      // Transform.scale only scales X and Y; Z stays at 1.0, so
      // getMaxScaleOnAxis() always returns 1.0. Read the X entry directly.
      return transform.transform.entry(0, 0);
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

      await tester.tap(find.text('Tap me'));
    });

    // -- Scale animation structure ------------------------------------

    testWidgets('contains Transform.scale for press feedback', (tester) async {
      await pumpPressable(tester);

      expect(findScaleTransform(tester), findsWidgets);
    });

    testWidgets('Transform.scale starts at scale 1.0', (tester) async {
      await pumpPressable(tester);

      expect(readScale(tester), 1.0);
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
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      // Pump a frame so the GestureDetector processes the pointer-down event
      // and fires onTapDown, which starts the spring animation.
      await tester.pump();
      // Pump real-time frames so the SpringSimulation can advance.
      await tester.pump(const Duration(milliseconds: 300));

      expect(readScale(tester), closeTo(0.95, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('scales back to 1.0 on tap up', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(readScale(tester), closeTo(1.0, 0.01));
    });

    testWidgets('scales back to 1.0 on tap cancel', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(readScale(tester), closeTo(1.0, 0.01));
    });

    // -- Custom scale factor ------------------------------------------

    testWidgets('respects custom scaleDown value', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
        scaleDown: 0.8,
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(readScale(tester), closeTo(0.8, 0.01));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    // -- Rapid tap stability ------------------------------------------

    testWidgets('handles rapid consecutive taps without error', (tester) async {
      var tapCount = 0;
      await pumpPressable(
        tester,
        onPressed: () => tapCount++,
      );

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Tap me'));
        await tester.pump();
      }

      expect(tapCount, 5);
    });
  });
}
