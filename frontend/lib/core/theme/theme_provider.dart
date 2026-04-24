import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Theme options available in the app.
///
/// Includes standard light/dark/system modes plus high contrast variants
/// for users with visual accessibility needs.
enum ThemeOption {
  light,
  dark,
  system,
  highContrastLight,
  highContrastDark,
}

/// Extension to get display names for theme options.
extension ThemeOptionExtension on ThemeOption {
  String toKey() {
    return switch (this) {
      ThemeOption.light => 'light',
      ThemeOption.dark => 'dark',
      ThemeOption.system => 'system',
      ThemeOption.highContrastLight => 'highContrastLight',
      ThemeOption.highContrastDark => 'highContrastDark',
    };
  }

  static ThemeOption fromKey(String key) {
    return switch (key) {
      'light' => ThemeOption.light,
      'dark' => ThemeOption.dark,
      'system' => ThemeOption.system,
      'highContrastLight' => ThemeOption.highContrastLight,
      'highContrastDark' => ThemeOption.highContrastDark,
      _ => ThemeOption.system,
    };
  }
}

/// SharedPreferences key for storing the theme option.
const _kThemeOptionKey = 'theme_option';

/// Provider that loads and watches the user's theme option preference.
///
/// Returns [ThemeOption.system] by default (respects system theme).
final themeOptionProvider =
    StateNotifierProvider<ThemeOptionNotifier, ThemeOption>(
  (ref) => ThemeOptionNotifier(),
);

/// Notifier that manages theme option persistence and updates.
class ThemeOptionNotifier extends StateNotifier<ThemeOption> {
  ThemeOptionNotifier() : super(ThemeOption.system) {
    _loadThemeOption();
  }

  /// Load the saved theme option from SharedPreferences.
  Future<void> _loadThemeOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_kThemeOptionKey);
      if (key != null) {
        state = ThemeOptionExtension.fromKey(key);
      }
    } catch (_) {
      // If loading fails, keep the default (system)
    }
  }

  /// Set a new theme option and persist it.
  Future<void> setThemeOption(ThemeOption option) async {
    state = option;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeOptionKey, option.toKey());
    } catch (_) {
      // If saving fails, the state is still updated in memory
    }
  }
}

/// Selects the appropriate ThemeData based on the current [ThemeOption].
///
/// This is a computed provider that depends on [themeOptionProvider].
/// Watch this provider in [MaterialApp.theme] and [MaterialApp.darkTheme].
///
/// For high contrast themes, returns the appropriate high contrast variant.
/// For system mode, returns null so that MaterialApp can use themeMode.
ThemeData? selectThemeData(ThemeOption option, Brightness systemBrightness) {
  return switch (option) {
    ThemeOption.light => AppTheme.lightTheme(),
    ThemeOption.dark => AppTheme.darkTheme(),
    ThemeOption.highContrastLight => AppTheme.highContrastLightTheme(),
    ThemeOption.highContrastDark => AppTheme.highContrastDarkTheme(),
    ThemeOption.system => null, // Let themeMode handle it
  };
}

/// Selects the appropriate [ThemeMode] based on the current [ThemeOption].
///
/// High contrast themes override the system setting, so we return
/// [ThemeMode.light] or [ThemeMode.dark] explicitly for those.
ThemeMode selectThemeMode(ThemeOption option) {
  return switch (option) {
    ThemeOption.light || ThemeOption.highContrastLight => ThemeMode.light,
    ThemeOption.dark || ThemeOption.highContrastDark => ThemeMode.dark,
    ThemeOption.system => ThemeMode.system,
  };
}

/// Returns true if the current theme option is a high contrast variant.
bool isHighContrast(ThemeOption option) {
  return switch (option) {
    ThemeOption.highContrastLight || ThemeOption.highContrastDark => true,
    _ => false,
  };
}
