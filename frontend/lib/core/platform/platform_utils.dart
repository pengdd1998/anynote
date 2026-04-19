import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  /// Returns true when running on macOS.
  static bool get isMacOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS;
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

  /// The platform-appropriate primary modifier key label for shortcuts.
  ///
  /// Returns "Cmd" on macOS and "Ctrl" on all other platforms.
  static String get modifierLabel {
    if (isMacOS) return 'Cmd';
    return 'Ctrl';
  }
}
