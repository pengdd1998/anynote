import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  LocaleNotifier() : super(const Locale('en')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null) {
      state = Locale(saved);
    }
    // If no saved preference, the default 'en' remains.
    // The MaterialApp will use system locale as fallback when the
    // provider value does not match any supported locale.
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
    state = const Locale('en');
  }
}
