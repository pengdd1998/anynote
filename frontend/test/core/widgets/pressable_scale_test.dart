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

      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('Transform.scale starts at scale 1.0', (tester) async {
      await pumpPressable(tester);

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      // Matrix4 scale at (0,0) should be 1.0 initially.
      expect(transform.transform.getMaxScaleOnAxis(), 1.0);
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
      await tester.pumpAndSettle();

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      // Scale should be close to scaleDown (0.95) after spring settles.
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(0.95, 0.01));

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
      await tester.pumpAndSettle();

      await gesture.up();
      await tester.pumpAndSettle();

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    });

    testWidgets('scales back to 1.0 on tap cancel', (tester) async {
      await pumpPressable(
        tester,
        onPressed: () {},
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Tap me')));
      await tester.pumpAndSettle();

      await gesture.cancel();
      await tester.pumpAndSettle();

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
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
      await tester.pumpAndSettle();

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(0.8, 0.01));

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
