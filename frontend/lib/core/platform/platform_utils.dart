import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

/// Platform utility helpers that are safe to use on all platforms (including web).
///
/// Use these instead of `dart:io` Platform checks to avoid compile-time
/// errors on web builds.
class PlatformUtils {
  PlatformUtils._();

  /// Returns true when running on a desktop OS (macOS, Windows, Linux).
  ///
  /// On web this always returns false regardless of the host OS, because web
  /// builds cannot import `dart:io`.
  static bool get isDesktop {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  /// Returns true when running on a mobile OS (Android, iOS).
  ///
  /// On web this always returns false. Use [isTouchDevice] for a runtime
  /// check that includes mobile-sized web viewports.
  static bool get isMobile {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  /// Returns true when running in a web browser.
  static bool get isWeb => kIsWeb;

  /// Returns true when running on an Apple platform (macOS or iOS).
  static bool get isApple {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns true when running on macOS.
  static bool get isMacOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Returns true when running on iOS.
  static bool get isIOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns true when running on Windows.
  static bool get isWindows {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Returns true when running on Linux.
  static bool get isLinux {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Returns true when running on Android.
  static bool get isAndroid {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether the device is expected to be primarily touch-driven.
  ///
  /// Returns true on mobile platforms (Android, iOS) and on web. Desktop
  /// platforms (macOS, Windows, Linux) return false. This is a static
  /// heuristic -- for a more accurate check, use `MediaQuery` to detect
  /// touch capabilities at runtime.
  static bool get isTouchDevice {
    if (kIsWeb) return true;
    return isMobile;
  }

  /// The platform-appropriate primary modifier key label for shortcuts.
  ///
  /// Returns "Cmd" on macOS and "Ctrl" on all other platforms.
  static String get modifierLabel {
    if (isMacOS) return 'Cmd';
    return 'Ctrl';
  }

  /// The [LogicalKeyboardKey] for the primary modifier on this platform.
  ///
  /// Returns [LogicalKeyboardKey.meta] (Cmd) on macOS and
  /// [LogicalKeyboardKey.control] on all other platforms.
  static LogicalKeyboardKey get primaryModifierKey {
    if (isMacOS) return LogicalKeyboardKey.meta;
    return LogicalKeyboardKey.control;
  }
}
