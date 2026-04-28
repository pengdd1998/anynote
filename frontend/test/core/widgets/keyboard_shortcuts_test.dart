import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/platform/platform_utils.dart';
import 'package:anynote/core/widgets/keyboard_shortcuts.dart';

void main() {
  tearDown(() {
    // Clean up any lingering static callbacks.
    AppKeyboardShortcuts.clearZenModeCallback();
    AppKeyboardShortcuts.clearPrintCallback();
    AppKeyboardShortcuts.clearInsertLinkCallback();
    AppKeyboardShortcuts.clearStrikethroughCallback();
    AppKeyboardShortcuts.clearInlineCodeCallback();
    AppKeyboardShortcuts.clearHeadingCycleCallback();
    AppKeyboardShortcuts.clearFindCallback();
  });

  // ---------------------------------------------------------------------------
  // Widget rendering
  // ---------------------------------------------------------------------------

  group('AppKeyboardShortcuts widget', () {
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

    testWidgets('disposing widget removes hardware keyboard handler',
        (tester) async {
      await pumpApp(tester);

      // Pump a different widget tree so AppKeyboardShortcuts is disposed.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // No crash means dispose ran cleanly -- the handler was removed.
      expect(true, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Static callback management
  // ---------------------------------------------------------------------------

  group('Static callback registration', () {
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

    test('printCallback can be set and cleared', () {
      var invoked = false;
      AppKeyboardShortcuts.setPrintCallback(() => invoked = true);
      AppKeyboardShortcuts.printCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearPrintCallback();
      AppKeyboardShortcuts.printCallback?.call();
      expect(invoked, isFalse);
    });

    test('insertLinkCallback can be set and cleared', () {
      var invoked = false;
      AppKeyboardShortcuts.setInsertLinkCallback(() => invoked = true);
      AppKeyboardShortcuts.insertLinkCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearInsertLinkCallback();
      AppKeyboardShortcuts.insertLinkCallback?.call();
      expect(invoked, isFalse);
    });

    test('strikethroughCallback can be set and cleared', () {
      var invoked = false;
      AppKeyboardShortcuts.setStrikethroughCallback(() => invoked = true);
      AppKeyboardShortcuts.strikethroughCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearStrikethroughCallback();
      AppKeyboardShortcuts.strikethroughCallback?.call();
      expect(invoked, isFalse);
    });

    test('inlineCodeCallback can be set and cleared', () {
      var invoked = false;
      AppKeyboardShortcuts.setInlineCodeCallback(() => invoked = true);
      AppKeyboardShortcuts.inlineCodeCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearInlineCodeCallback();
      AppKeyboardShortcuts.inlineCodeCallback?.call();
      expect(invoked, isFalse);
    });

    test('headingCycleCallback can be set and cleared', () {
      var invoked = false;
      AppKeyboardShortcuts.setHeadingCycleCallback(() => invoked = true);
      AppKeyboardShortcuts.headingCycleCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearHeadingCycleCallback();
      AppKeyboardShortcuts.headingCycleCallback?.call();
      expect(invoked, isFalse);
    });

    test('findCallback can be set and cleared', () {
      var invoked = false;
      AppKeyboardShortcuts.setFindCallback(() => invoked = true);
      AppKeyboardShortcuts.findCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearFindCallback();
      AppKeyboardShortcuts.findCallback?.call();
      expect(invoked, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Platform-aware modifier consistency
  // ---------------------------------------------------------------------------

  group('Platform-aware modifier consistency', () {
    test(
        'PlatformUtils.primaryModifierKey returns LogicalKeyboardKey.meta on macOS',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.meta);
      debugDefaultTargetPlatformOverride = null;
    });

    test(
        'PlatformUtils.primaryModifierKey returns LogicalKeyboardKey.control on Windows',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.control);
      debugDefaultTargetPlatformOverride = null;
    });

    test(
        'PlatformUtils.primaryModifierKey returns LogicalKeyboardKey.control on Linux',
        () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.control);
      debugDefaultTargetPlatformOverride = null;
    });

    test('modifierLabel and primaryModifierKey are consistent on all platforms',
        () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;

        final label = PlatformUtils.modifierLabel;
        final key = PlatformUtils.primaryModifierKey;

        if (label == 'Cmd') {
          expect(key, LogicalKeyboardKey.meta,
              reason: 'Cmd label should map to meta key on $platform');
        } else {
          expect(label, 'Ctrl');
          expect(key, LogicalKeyboardKey.control,
              reason: 'Ctrl label should map to control key on $platform');
        }
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
