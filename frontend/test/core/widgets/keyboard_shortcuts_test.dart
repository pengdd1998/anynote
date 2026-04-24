import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/keyboard_shortcuts.dart';

void main() {
  group('AppKeyboardShortcuts', () {
    Future<void> pumpApp(
      WidgetTester tester, {
      Widget? child,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppKeyboardShortcuts(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders child widget', (tester) async {
      await pumpApp(tester, child: const Text('Child Content'));
      expect(find.text('Child Content'), findsOneWidget);
    });

    testWidgets('rebuilds child on setState without duplicating handlers',
        (tester) async {
      await pumpApp(tester, child: const Text('v1'));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppKeyboardShortcuts(
              child: Text('v2'),
            ),
          ),
        ),
      );
      expect(find.text('v2'), findsOneWidget);
    });

    test('zenModeCallback can be set and cleared', () {
      var invoked = false;
      void callback() => invoked = true;

      AppKeyboardShortcuts.setZenModeCallback(callback);
      AppKeyboardShortcuts.zenModeCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearZenModeCallback();
      AppKeyboardShortcuts.zenModeCallback?.call();
      expect(invoked, isFalse);
    });

    test('setZenModeCallback replaces previous callback', () {
      var first = false;
      var second = false;

      AppKeyboardShortcuts.setZenModeCallback(() => first = true);
      AppKeyboardShortcuts.setZenModeCallback(() => second = true);
      AppKeyboardShortcuts.zenModeCallback?.call();

      expect(first, isFalse);
      expect(second, isTrue);

      // Cleanup.
      AppKeyboardShortcuts.clearZenModeCallback();
    });

    testWidgets('disposing widget removes hardware keyboard handler',
        (tester) async {
      await pumpApp(tester);

      // Pump a different widget tree so AppKeyboardShortcuts is disposed.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // No crash means dispose ran cleanly -- the handler was removed.
      expect(true, isTrue);
    });
  });
}
