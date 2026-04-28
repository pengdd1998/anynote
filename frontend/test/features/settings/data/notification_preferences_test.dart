import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/features/settings/data/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('defaults all fields to true', () {
      final prefs = NotificationPreferences();
      expect(prefs.reminderNotifications, isTrue);
      expect(prefs.syncConflictNotifications, isTrue);
      expect(prefs.shareNotifications, isTrue);
      expect(prefs.pushNotifications, isTrue);
    });

    test('fromJson parses all fields', () {
      final json = {
        'reminderNotifications': false,
        'syncConflictNotifications': true,
        'shareNotifications': false,
        'pushNotifications': true,
      };
      final prefs = NotificationPreferences.fromJson(json);
      expect(prefs.reminderNotifications, isFalse);
      expect(prefs.syncConflictNotifications, isTrue);
      expect(prefs.shareNotifications, isFalse);
      expect(prefs.pushNotifications, isTrue);
    });

    test('toJson round-trips correctly', () {
      final prefs = NotificationPreferences(
        reminderNotifications: false,
        syncConflictNotifications: true,
        shareNotifications: false,
        pushNotifications: true,
      );
      final json = prefs.toJson();
      final restored = NotificationPreferences.fromJson(json);
      expect(restored, equals(prefs));
    });

    test('handles missing fields in fromJson with defaults', () {
      final prefs = NotificationPreferences.fromJson({});
      expect(prefs.reminderNotifications, isTrue);
      expect(prefs.syncConflictNotifications, isTrue);
      expect(prefs.shareNotifications, isTrue);
      expect(prefs.pushNotifications, isTrue);
    });

    test('copyWith only overrides specified fields', () {
      const prefs = NotificationPreferences(reminderNotifications: false);
      final copied = prefs.copyWith(pushNotifications: false);
      expect(copied.reminderNotifications, isFalse);
      expect(copied.pushNotifications, isFalse);
      expect(copied.syncConflictNotifications, isTrue);
    });

    test('equality works correctly', () {
      const a = NotificationPreferences();
      const b = NotificationPreferences();
      expect(a, equals(b));

      const c = NotificationPreferences(reminderNotifications: false);
      expect(a, isNot(equals(c)));
    });
  });

  group('NotificationPreferences persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('toJson produces valid JSON', () {
      final prefs = NotificationPreferences();
      final jsonStr = jsonEncode(prefs.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final restored = NotificationPreferences.fromJson(decoded);
      expect(restored, equals(prefs));
    });

    test('stored preferences are loaded correctly', () async {
      final original = NotificationPreferences(
        reminderNotifications: false,
        syncConflictNotifications: true,
        shareNotifications: false,
        pushNotifications: true,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notification_preferences',
        jsonEncode(original.toJson()),
      );

      final raw = prefs.getString('notification_preferences');
      expect(raw, isNotNull);
      final loaded = NotificationPreferences.fromJson(
        jsonDecode(raw!) as Map<String, dynamic>,
      );
      expect(loaded, equals(original));
    });
  });
}
