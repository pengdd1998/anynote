import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/locale/locale_provider.dart';

void main() {
  group('LocaleNotifier', () {
    late ProviderContainer container;

    setUp(() {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state defaults to English', () {
      final notifier = container.read(localeProvider.notifier);
      // The notifier starts with Locale('en') and loads saved prefs async.
      expect(notifier.state, const Locale('en'));
    });

    test('setLocale updates state', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('ja'));

      expect(notifier.state, const Locale('ja'));
    });

    test('setLocale persists preference to SharedPreferences', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('zh'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'zh');
    });

    test('setLocale with different locales updates correctly', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('ko'));
      expect(notifier.state, const Locale('ko'));

      await notifier.setLocale(const Locale('en'));
      expect(notifier.state, const Locale('en'));
    });

    test('clearLocale resets to English default', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('ja'));
      expect(notifier.state, const Locale('ja'));

      await notifier.clearLocale();
      expect(notifier.state, const Locale('en'));
    });

    test('clearLocale removes stored preference', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('ko'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'ko');

      await notifier.clearLocale();

      final prefsAfter = await SharedPreferences.getInstance();
      expect(prefsAfter.getString('app_locale'), isNull);
    });

    test('loads saved locale on construction', () async {
      // Pre-set a saved locale before creating the notifier
      SharedPreferences.setMockInitialValues({'app_locale': 'ja'});

      final freshContainer = ProviderContainer();
      addTearDown(() => freshContainer.dispose());

      // Read the provider to trigger lazy construction and _loadSavedLocale.
      freshContainer.read(localeProvider);

      // Wait for the async _loadSavedLocale to complete
      await Future.delayed(const Duration(milliseconds: 50));

      final state = freshContainer.read(localeProvider);
      expect(state, const Locale('ja'));
    });

    test('falls back to English when no saved preference', () async {
      SharedPreferences.setMockInitialValues({});

      final freshContainer = ProviderContainer();
      addTearDown(() => freshContainer.dispose());

      await Future.delayed(const Duration(milliseconds: 50));

      final state = freshContainer.read(localeProvider);
      expect(state, const Locale('en'));
    });

    test('locale provider is accessible via container.read', () {
      final state = container.read(localeProvider);
      expect(state, isA<Locale>());
    });

    test('multiple setLocale calls in sequence work correctly', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('en'));
      await notifier.setLocale(const Locale('ja'));
      await notifier.setLocale(const Locale('ko'));
      await notifier.setLocale(const Locale('zh'));

      expect(notifier.state, const Locale('zh'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'zh');
    });

    test('setLocale then clearLocale then setLocale again', () async {
      final notifier = container.read(localeProvider.notifier);

      await notifier.setLocale(const Locale('ja'));
      expect(notifier.state, const Locale('ja'));

      await notifier.clearLocale();
      expect(notifier.state, const Locale('en'));

      await notifier.setLocale(const Locale('ko'));
      expect(notifier.state, const Locale('ko'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), 'ko');
    });
  });

  group('localeProvider', () {
    test('provider is a StateNotifierProvider', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final provider = localeProvider;
      expect(provider, isA<StateNotifierProvider<LocaleNotifier, Locale>>());
    });

    test('provider returns Locale type', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final locale = container.read(localeProvider);
      expect(locale, isA<Locale>());
    });
  });
}
