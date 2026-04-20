import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/platform/platform_utils.dart';

void main() {
  // Save original value so we can restore it after each test.
  final originalPlatform = debugDefaultTargetPlatformOverride;

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  // ---------------------------------------------------------------------------
  // isDesktop
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isDesktop', () {
    test('returns true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isDesktop, isTrue);
    });

    test('returns true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isDesktop, isTrue);
    });

    test('returns true on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isDesktop, isTrue);
    });

    test('returns false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.isDesktop, isFalse);
    });

    test('returns false on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isDesktop, isFalse);
    });

    test('returns false on Fuchsia', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect(PlatformUtils.isDesktop, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isMacOS
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isMacOS', () {
    test('returns true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isMacOS, isTrue);
    });

    test('returns false on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isMacOS, isFalse);
    });

    test('returns false on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isMacOS, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isWindows
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isWindows', () {
    test('returns true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isWindows, isTrue);
    });

    test('returns false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isWindows, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isLinux
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isLinux', () {
    test('returns true on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isLinux, isTrue);
    });

    test('returns false on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isLinux, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // modifierLabel
  // ---------------------------------------------------------------------------

  group('PlatformUtils.modifierLabel', () {
    test('returns Cmd on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.modifierLabel, 'Cmd');
    });

    test('returns Ctrl on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.modifierLabel, 'Ctrl');
    });

    test('returns Ctrl on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.modifierLabel, 'Ctrl');
    });

    test('returns Ctrl on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.modifierLabel, 'Ctrl');
    });

    test('returns Ctrl on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.modifierLabel, 'Ctrl');
    });
  });
}
