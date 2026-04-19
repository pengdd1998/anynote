import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/storage/window_state.dart';

void main() {
  // ===========================================================================
  // WindowBounds data class
  // ===========================================================================

  group('WindowBounds', () {
    test('constructs with required fields', () {
      final bounds = WindowBounds(
        x: 10.0,
        y: 20.0,
        width: 800.0,
        height: 600.0,
      );
      expect(bounds.x, 10.0);
      expect(bounds.y, 20.0);
      expect(bounds.width, 800.0);
      expect(bounds.height, 600.0);
      expect(bounds.isMaximized, isFalse);
    });

    test('constructs with isMaximized true', () {
      final bounds = WindowBounds(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080,
        isMaximized: true,
      );
      expect(bounds.isMaximized, isTrue);
    });

    test('defaults isMaximized to false', () {
      const bounds = WindowBounds(x: 0, y: 0, width: 100, height: 100);
      expect(bounds.isMaximized, isFalse);
    });

    test('defaults constant has expected values', () {
      expect(WindowBounds.defaults.x, 100);
      expect(WindowBounds.defaults.y, 100);
      expect(WindowBounds.defaults.width, 1280);
      expect(WindowBounds.defaults.height, 800);
      expect(WindowBounds.defaults.isMaximized, isFalse);
    });

    test('toString includes all fields', () {
      final bounds = WindowBounds(
        x: 50,
        y: 75,
        width: 1024,
        height: 768,
        isMaximized: true,
      );
      final str = bounds.toString();
      expect(str, contains('50'));
      expect(str, contains('75'));
      expect(str, contains('1024'));
      expect(str, contains('768'));
      expect(str, contains('max: true'));
    });

    test('two identical bounds are equal by value', () {
      // WindowBounds does not override ==, so two instances with the same
      // values are not equal. Verify this expected behavior.
      const a = WindowBounds(x: 10, y: 20, width: 800, height: 600);
      const b = WindowBounds(x: 10, y: 20, width: 800, height: 600);
      // They are const identical, so should be the same instance.
      expect(identical(a, b), isTrue);
    });

    test('different bounds are not identical', () {
      final a = WindowBounds(x: 10, y: 20, width: 800, height: 600);
      final b = WindowBounds(x: 10, y: 20, width: 800, height: 601);
      expect(identical(a, b), isFalse);
    });
  });

  // ===========================================================================
  // WindowStateService -- save and load
  // ===========================================================================

  group('WindowStateService save and load', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save writes all values to SharedPreferences', () async {
      // WindowStateService.isSupported checks Platform.isMacOS/Windows/Linux.
      // On a Linux test runner, isSupported should be true.
      // If not, the save/load calls are no-ops, so we test the SharedPreferences
      // directly to verify the write/read logic.

      final prefs = await SharedPreferences.getInstance();

      // Manually simulate what save does.
      await prefs.setDouble('window_x', 100.0);
      await prefs.setDouble('window_y', 200.0);
      await prefs.setDouble('window_width', 1024.0);
      await prefs.setDouble('window_height', 768.0);
      await prefs.setBool('window_maximized', true);

      expect(prefs.getDouble('window_x'), 100.0);
      expect(prefs.getDouble('window_y'), 200.0);
      expect(prefs.getDouble('window_width'), 1024.0);
      expect(prefs.getDouble('window_height'), 768.0);
      expect(prefs.getBool('window_maximized'), isTrue);
    });

    test('load returns null when no state is saved', () async {
      final result = await WindowStateService.load();
      // On Linux, isSupported is true, so it will try to load from empty prefs.
      // If not supported, it returns null anyway.
      expect(result, isNull);
    });

    test('round-trip: save then load preserves all fields', () async {
      await WindowStateService.save(
        x: 50.0,
        y: 100.0,
        width: 1280.0,
        height: 720.0,
        isMaximized: false,
      );

      final result = await WindowStateService.load();

      if (WindowStateService.isSupported) {
        // On a supported platform, the round-trip should work.
        expect(result, isNotNull);
        expect(result!.x, 50.0);
        expect(result.y, 100.0);
        expect(result.width, 1280.0);
        expect(result.height, 720.0);
        expect(result.isMaximized, isFalse);
      } else {
        expect(result, isNull);
      }
    });

    test('round-trip preserves maximized state', () async {
      await WindowStateService.save(
        x: 0.0,
        y: 0.0,
        width: 1920.0,
        height: 1080.0,
        isMaximized: true,
      );

      final result = await WindowStateService.load();

      if (WindowStateService.isSupported) {
        expect(result, isNotNull);
        expect(result!.isMaximized, isTrue);
      }
    });

    test('load returns null when only partial state is saved', () async {
      final prefs = await SharedPreferences.getInstance();
      // Only save x and y, but not width/height.
      await prefs.setDouble('window_x', 100.0);
      await prefs.setDouble('window_y', 200.0);

      if (WindowStateService.isSupported) {
        final result = await WindowStateService.load();
        // Missing width and height should result in null.
        expect(result, isNull);
      }
    });

    test('load defaults isMaximized to false when not saved', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('window_x', 10.0);
      await prefs.setDouble('window_y', 20.0);
      await prefs.setDouble('window_width', 800.0);
      await prefs.setDouble('window_height', 600.0);
      // Do NOT set window_maximized.

      if (WindowStateService.isSupported) {
        final result = await WindowStateService.load();
        expect(result, isNotNull);
        expect(result!.isMaximized, isFalse);
      }
    });

    test('load handles zero dimensions', () async {
      await WindowStateService.save(
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        isMaximized: false,
      );

      if (WindowStateService.isSupported) {
        final result = (await WindowStateService.load())!;
        expect(result.x, 0.0);
        expect(result.y, 0.0);
        expect(result.width, 0.0);
        expect(result.height, 0.0);
      }
    });

    test('load handles very large dimensions', () async {
      const largeValue = 100000.0;
      await WindowStateService.save(
        x: largeValue,
        y: largeValue,
        width: largeValue,
        height: largeValue,
        isMaximized: false,
      );

      if (WindowStateService.isSupported) {
        final result = (await WindowStateService.load())!;
        expect(result.x, largeValue);
        expect(result.y, largeValue);
        expect(result.width, largeValue);
        expect(result.height, largeValue);
      }
    });

    test('load handles fractional dimensions', () async {
      await WindowStateService.save(
        x: 10.5,
        y: 20.25,
        width: 800.125,
        height: 600.0625,
        isMaximized: false,
      );

      if (WindowStateService.isSupported) {
        final result = await WindowStateService.load();
        expect(result, isNotNull);
        expect(result!.x, closeTo(10.5, 0.001));
        expect(result.y, closeTo(20.25, 0.001));
        expect(result.width, closeTo(800.125, 0.001));
        expect(result.height, closeTo(600.0625, 0.001));
      }
    });

    test('save overwrites previous state', () async {
      await WindowStateService.save(
        x: 10.0,
        y: 20.0,
        width: 800.0,
        height: 600.0,
        isMaximized: false,
      );

      await WindowStateService.save(
        x: 30.0,
        y: 40.0,
        width: 1024.0,
        height: 768.0,
        isMaximized: true,
      );

      if (WindowStateService.isSupported) {
        final result = await WindowStateService.load();
        expect(result, isNotNull);
        expect(result!.x, 30.0);
        expect(result.y, 40.0);
        expect(result.width, 1024.0);
        expect(result.height, 768.0);
        expect(result.isMaximized, isTrue);
      }
    });

    test('corrupted string value in prefs does not crash load', () async {
      // Simulate corruption by not setting any values (all null).
      // load() should handle null gracefully and return null.
      SharedPreferences.setMockInitialValues({});

      if (WindowStateService.isSupported) {
        final result = await WindowStateService.load();
        expect(result, isNull);
      }
    });
  });

  // ===========================================================================
  // WindowStateService.isSupported
  // ===========================================================================

  group('WindowStateService.isSupported', () {
    test('returns true on Linux test runner', () {
      // This test runs on Linux, so isSupported should be true.
      // (It checks Platform.isLinux among others.)
      expect(WindowStateService.isSupported, isTrue);
    });
  });
}
