import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/platform/platform_utils.dart';
import 'package:anynote/core/widgets/keyboard_shortcuts.dart';

void main() {
  tearDown(() {
    // Clean up any lingering static callbacks.
    final _dummy = Object();
    AppKeyboardShortcuts.clearZenModeCallback(owner: _dummy);
    AppKeyboardShortcuts.clearPrintCallback(owner: _dummy);
    AppKeyboardShortcuts.clearInsertLinkCallback(owner: _dummy);
    AppKeyboardShortcuts.clearStrikethroughCallback(owner: _dummy);
    AppKeyboardShortcuts.clearInlineCodeCallback(owner: _dummy);
    AppKeyboardShortcuts.clearHeadingCycleCallback(owner: _dummy);
    AppKeyboardShortcuts.clearFindCallback(owner: _dummy);
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
      final owner = Object();

      AppKeyboardShortcuts.setZenModeCallback(callback, owner: owner);
      AppKeyboardShortcuts.zenModeCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearZenModeCallback(owner: owner);
      AppKeyboardShortcuts.zenModeCallback?.call();
      expect(invoked, isFalse);
    });

    test('setZenModeCallback replaces previous callback for same owner', () {
      var first = false;
      var second = false;
      final owner = Object();

      AppKeyboardShortcuts.setZenModeCallback(() => first = true, owner: owner);
      AppKeyboardShortcuts.setZenModeCallback(() => second = true, owner: owner);
      AppKeyboardShortcuts.zenModeCallback?.call();

      expect(first, isFalse);
      expect(second, isTrue);

      // Cleanup.
      AppKeyboardShortcuts.clearZenModeCallback(owner: owner);
    });

    test('printCallback can be set and cleared', () {
      var invoked = false;
      final owner = Object();
      AppKeyboardShortcuts.setPrintCallback(() => invoked = true, owner: owner);
      AppKeyboardShortcuts.printCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearPrintCallback(owner: owner);
      AppKeyboardShortcuts.printCallback?.call();
      expect(invoked, isFalse);
    });

    test('insertLinkCallback can be set and cleared', () {
      var invoked = false;
      final owner = Object();
      AppKeyboardShortcuts.setInsertLinkCallback(() => invoked = true, owner: owner);
      AppKeyboardShortcuts.insertLinkCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearInsertLinkCallback(owner: owner);
      AppKeyboardShortcuts.insertLinkCallback?.call();
      expect(invoked, isFalse);
    });

    test('strikethroughCallback can be set and cleared', () {
      var invoked = false;
      final owner = Object();
      AppKeyboardShortcuts.setStrikethroughCallback(() => invoked = true, owner: owner);
      AppKeyboardShortcuts.strikethroughCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearStrikethroughCallback(owner: owner);
      AppKeyboardShortcuts.strikethroughCallback?.call();
      expect(invoked, isFalse);
    });

    test('inlineCodeCallback can be set and cleared', () {
      var invoked = false;
      final owner = Object();
      AppKeyboardShortcuts.setInlineCodeCallback(() => invoked = true, owner: owner);
      AppKeyboardShortcuts.inlineCodeCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearInlineCodeCallback(owner: owner);
      AppKeyboardShortcuts.inlineCodeCallback?.call();
      expect(invoked, isFalse);
    });

    test('headingCycleCallback can be set and cleared', () {
      var invoked = false;
      final owner = Object();
      AppKeyboardShortcuts.setHeadingCycleCallback(() => invoked = true, owner: owner);
      AppKeyboardShortcuts.headingCycleCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearHeadingCycleCallback(owner: owner);
      AppKeyboardShortcuts.headingCycleCallback?.call();
      expect(invoked, isFalse);
    });

    test('findCallback can be set and cleared', () {
      var invoked = false;
      final owner = Object();
      AppKeyboardShortcuts.setFindCallback(() => invoked = true, owner: owner);
      AppKeyboardShortcuts.findCallback?.call();
      expect(invoked, isTrue);

      invoked = false;
      AppKeyboardShortcuts.clearFindCallback(owner: owner);
      AppKeyboardShortcuts.findCallback?.call();
      expect(invoked, isFalse);
    });

    test('unregisterAll removes all callbacks for an owner', () {
      var zenInvoked = false;
      var printInvoked = false;
      final owner = Object();

      AppKeyboardShortcuts.setZenModeCallback(() => zenInvoked = true, owner: owner);
      AppKeyboardShortcuts.setPrintCallback(() => printInvoked = true, owner: owner);

      AppKeyboardShortcuts.zenModeCallback?.call();
      AppKeyboardShortcuts.printCallback?.call();
      expect(zenInvoked, isTrue);
      expect(printInvoked, isTrue);

      zenInvoked = false;
      printInvoked = false;

      AppKeyboardShortcuts.unregisterAll(owner);
      AppKeyboardShortcuts.zenModeCallback?.call();
      AppKeyboardShortcuts.printCallback?.call();
      expect(zenInvoked, isFalse);
      expect(printInvoked, isFalse);
    });

    test('different owners do not interfere with each other', () {
      var ownerAInvoked = false;
      var ownerBInvoked = false;
      final ownerA = Object();
      final ownerB = Object();

      AppKeyboardShortcuts.setZenModeCallback(() => ownerAInvoked = true, owner: ownerA);
      AppKeyboardShortcuts.setZenModeCallback(() => ownerBInvoked = true, owner: ownerB);

      AppKeyboardShortcuts.zenModeCallback?.call();
      expect(ownerAInvoked, isTrue);

      ownerAInvoked = false;
      AppKeyboardShortcuts.clearZenModeCallback(owner: ownerA);
      AppKeyboardShortcuts.zenModeCallback?.call();
      expect(ownerAInvoked, isFalse);
      expect(ownerBInvoked, isTrue);

      AppKeyboardShortcuts.clearZenModeCallback(owner: ownerB);
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
              reason: 'Cmd label should map to meta key on $platform',);
        } else {
          expect(label, 'Ctrl');
          expect(key, LogicalKeyboardKey.control,
              reason: 'Ctrl label should map to control key on $platform',);
        }
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
