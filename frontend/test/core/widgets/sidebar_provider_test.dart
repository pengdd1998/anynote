import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/widgets/sidebar_provider.dart';

void main() {
  group('SidebarVisibilityNotifier', () {
    late ProviderContainer container;
    late SidebarVisibilityNotifier notifier;

    setUp(() {
      // SharedPreferences.setMockInitialValues must be called before
      // SharedPreferences.getInstance is invoked.
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      notifier = container.read(sidebarVisibleProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    // -- Initialization -----------------------------------------------------

    test('initial state is true (sidebar visible by default)', () {
      // Since the async _load hasn't completed yet, state is the constructor
      // default of true.
      expect(notifier.state, isTrue);
    });

    test('loads saved value from SharedPreferences', () async {
      // Set up mock with a saved value of false.
      SharedPreferences.setMockInitialValues({'sidebar_visible': false});

      final localContainer = ProviderContainer();
      addTearDown(() => localContainer.dispose());

      final localNotifier =
          localContainer.read(sidebarVisibleProvider.notifier);

      // Wait for the async _load to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(localNotifier.state, isFalse);
    });

    test('remains true when SharedPreferences has no saved value', () async {
      SharedPreferences.setMockInitialValues({});

      final localContainer = ProviderContainer();
      addTearDown(() => localContainer.dispose());

      final localNotifier =
          localContainer.read(sidebarVisibleProvider.notifier);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(localNotifier.state, isTrue);
    });

    // -- Toggle -------------------------------------------------------------

    test('toggle flips state from true to false', () async {
      expect(notifier.state, isTrue);

      await notifier.toggle();

      expect(notifier.state, isFalse);
    });

    test('toggle flips state from false back to true', () async {
      await notifier.toggle(); // true -> false
      expect(notifier.state, isFalse);

      await notifier.toggle(); // false -> true
      expect(notifier.state, isTrue);
    });

    test('toggle persists value to SharedPreferences', () async {
      await notifier.toggle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sidebar_visible'), isFalse);
    });

    test('multiple toggles persist the final value', () async {
      await notifier.toggle(); // false
      await notifier.toggle(); // true
      await notifier.toggle(); // false

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sidebar_visible'), isFalse);
    });

    // -- SetVisible ---------------------------------------------------------

    test('setVisible sets state to true', () async {
      await notifier.toggle(); // set to false first
      expect(notifier.state, isFalse);

      await notifier.setVisible(true);

      expect(notifier.state, isTrue);
    });

    test('setVisible sets state to false', () async {
      expect(notifier.state, isTrue);

      await notifier.setVisible(false);

      expect(notifier.state, isFalse);
    });

    test('setVisible persists value to SharedPreferences', () async {
      await notifier.setVisible(false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sidebar_visible'), isFalse);
    });

    test('setVisible with same value is idempotent', () async {
      expect(notifier.state, isTrue);

      await notifier.setVisible(true); // already true

      expect(notifier.state, isTrue);
    });
  });

  group('sidebarVisibleProvider', () {
    test('provider returns SidebarVisibilityNotifier', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final notifier = container.read(sidebarVisibleProvider.notifier);
      expect(notifier, isA<SidebarVisibilityNotifier>());
    });

    test('provider exposes bool state', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final state = container.read(sidebarVisibleProvider);
      expect(state, isA<bool>());
    });
  });
}
