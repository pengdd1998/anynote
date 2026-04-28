import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  // isMobile
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isMobile', () {
    test('returns true on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.isMobile, isTrue);
    });

    test('returns true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isMobile, isTrue);
    });

    test('returns false on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isMobile, isFalse);
    });

    test('returns false on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isMobile, isFalse);
    });

    test('returns false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isMobile, isFalse);
    });

    test('returns false on Fuchsia', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect(PlatformUtils.isMobile, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isWeb
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isWeb', () {
    test('returns false in test environment', () {
      // Test environment is not web.
      expect(PlatformUtils.isWeb, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isApple
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isApple', () {
    test('returns true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isApple, isTrue);
    });

    test('returns true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isApple, isTrue);
    });

    test('returns false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.isApple, isFalse);
    });

    test('returns false on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isApple, isFalse);
    });

    test('returns false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isApple, isFalse);
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
  // isIOS
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isIOS', () {
    test('returns true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isIOS, isTrue);
    });

    test('returns false on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isIOS, isFalse);
    });

    test('returns false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.isIOS, isFalse);
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
  // isAndroid
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isAndroid', () {
    test('returns true on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.isAndroid, isTrue);
    });

    test('returns false on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isAndroid, isFalse);
    });

    test('returns false on Fuchsia', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect(PlatformUtils.isAndroid, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // isTouchDevice
  // ---------------------------------------------------------------------------

  group('PlatformUtils.isTouchDevice', () {
    test('returns true on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.isTouchDevice, isTrue);
    });

    test('returns true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.isTouchDevice, isTrue);
    });

    test('returns false on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.isTouchDevice, isFalse);
    });

    test('returns false on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.isTouchDevice, isFalse);
    });

    test('returns false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.isTouchDevice, isFalse);
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

  // ---------------------------------------------------------------------------
  // primaryModifierKey
  // ---------------------------------------------------------------------------

  group('PlatformUtils.primaryModifierKey', () {
    test('returns meta on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.meta);
    });

    test('returns control on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.control);
    });

    test('returns control on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.control);
    });

    test('returns control on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.control);
    });

    test('returns control on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PlatformUtils.primaryModifierKey, LogicalKeyboardKey.control);
    });
  });

  // ---------------------------------------------------------------------------
  // Mutual exclusivity
  // ---------------------------------------------------------------------------

  group('Platform categories are mutually exclusive', () {
    test('isDesktop and isMobile are never both true', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        // At most one should be true (both false on Fuchsia).
        final bothTrue = PlatformUtils.isDesktop && PlatformUtils.isMobile;
        expect(bothTrue, isFalse, reason: 'Both true on $platform');
      }
    });
  });
}
