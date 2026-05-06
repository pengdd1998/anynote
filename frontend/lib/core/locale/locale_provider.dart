import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Key used to persist the user's locale choice in SharedPreferences.
const _kLocaleKey = 'app_locale';

/// Provider that holds the current locale.
///
/// On first load it reads the persisted preference (if any) and falls back
/// to the system locale. When the user picks a new language the value is
/// written back to SharedPreferences so the choice survives app restarts.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Notifier that manages the locale with persistence.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_detectInitialLocale()) {
    _loadSavedLocale();
  }

  /// Detect the best initial locale from the system before any async
  /// storage read completes. This prevents the UI from briefly showing
  /// English when the user's device is set to zh/ja/ko.
  static Locale _detectInitialLocale() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final languageCode = systemLocale.languageCode;

    // Check if the system locale is one of our supported languages.
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == languageCode) {
        return supported;
      }
    }
    // Fallback: let MaterialApp handle locale resolution.
    return systemLocale;
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null) {
      state = Locale(saved);
    }
    // If no saved preference, keep the detected system locale.
  }

  /// Persist and apply a new locale.
  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  /// Reset to system default by clearing the stored preference.
  Future<void> clearLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLocaleKey);
    state = _detectInitialLocale();
  }
}
