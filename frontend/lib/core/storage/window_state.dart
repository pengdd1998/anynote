import 'dart:io' if (dart.library.js) 'dart:html';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Persists desktop window geometry (position, size, maximized state) so the
/// window can be restored to its last known bounds on the next launch.
///
/// Only meaningful on desktop platforms. Calling any method on mobile or web
/// is a safe no-op.
class WindowStateService {
  WindowStateService._();

  // SharedPreferences keys.
  static const _keyX = 'window_x';
  static const _keyY = 'window_y';
  static const _keyWidth = 'window_width';
  static const _keyHeight = 'window_height';
  static const _keyMaximized = 'window_maximized';

  /// Whether window state persistence is supported on the current platform.
  static bool get isSupported {
    if (kIsWeb) return false;
    // At compile time dart:io is available on native platforms.
    // The import stub above handles web.
    try {
      // ignore: unnecessary_null_comparison
      return !kIsWeb && Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  /// Save the current window bounds.
  static Future<void> save({
    required double x,
    required double y,
    required double width,
    required double height,
    required bool isMaximized,
  }) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyX, x);
    await prefs.setDouble(_keyY, y);
    await prefs.setDouble(_keyWidth, width);
    await prefs.setDouble(_keyHeight, height);
    await prefs.setBool(_keyMaximized, isMaximized);
  }

  /// Load the previously saved window bounds.
  ///
  /// Returns null if no state has been saved or the platform is unsupported.
  static Future<WindowBounds?> load() async {
    if (!isSupported) return null;
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);
    final width = prefs.getDouble(_keyWidth);
    final height = prefs.getDouble(_keyHeight);
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    return WindowBounds(
      x: x,
      y: y,
      width: width,
      height: height,
      isMaximized: prefs.getBool(_keyMaximized) ?? false,
    );
  }
}

/// Immutable snapshot of desktop window geometry.
class WindowBounds {
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isMaximized;

  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isMaximized = false,
  });

  /// Default size for a first launch when no saved state exists.
  static const WindowBounds defaults = WindowBounds(
    x: 100,
    y: 100,
    width: 1280,
    height: 800,
  );

  @override
  String toString() =>
      'WindowBounds(x: $x, y: $y, w: $width, h: $height, max: $isMaximized)';
}
