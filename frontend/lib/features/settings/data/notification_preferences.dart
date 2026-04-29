import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';

/// User-configurable notification preferences.
///
/// Each field controls a distinct notification channel. Stored as a JSON
/// string in SharedPreferences under [_prefsKey] so it survives app restarts.
class NotificationPreferences {
  final bool reminderNotifications;
  final bool syncConflictNotifications;
  final bool shareNotifications;
  final bool pushNotifications;

  const NotificationPreferences({
    this.reminderNotifications = true,
    this.syncConflictNotifications = true,
    this.shareNotifications = true,
    this.pushNotifications = true,
  });

  /// Deserialize from a JSON map.
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      reminderNotifications: json['reminderNotifications'] as bool? ?? true,
      syncConflictNotifications:
          json['syncConflictNotifications'] as bool? ?? true,
      shareNotifications: json['shareNotifications'] as bool? ?? true,
      pushNotifications: json['pushNotifications'] as bool? ?? true,
    );
  }

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'reminderNotifications': reminderNotifications,
        'syncConflictNotifications': syncConflictNotifications,
        'shareNotifications': shareNotifications,
        'pushNotifications': pushNotifications,
      };

  /// Create a copy with optional field overrides.
  NotificationPreferences copyWith({
    bool? reminderNotifications,
    bool? syncConflictNotifications,
    bool? shareNotifications,
    bool? pushNotifications,
  }) {
    return NotificationPreferences(
      reminderNotifications:
          reminderNotifications ?? this.reminderNotifications,
      syncConflictNotifications:
          syncConflictNotifications ?? this.syncConflictNotifications,
      shareNotifications: shareNotifications ?? this.shareNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          runtimeType == other.runtimeType &&
          reminderNotifications == other.reminderNotifications &&
          syncConflictNotifications == other.syncConflictNotifications &&
          shareNotifications == other.shareNotifications &&
          pushNotifications == other.pushNotifications;

  @override
  int get hashCode => Object.hash(
        reminderNotifications,
        syncConflictNotifications,
        shareNotifications,
        pushNotifications,
      );
}

/// SharedPreferences key for persisting notification preferences.
const _prefsKey = 'notification_preferences';

/// Riverpod notifier that manages [NotificationPreferences] with
/// persistence via SharedPreferences and backend sync when authenticated.
class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() {
    // Kick off async load; defaults are used until load completes.
    _loadFromPrefs();
    return const NotificationPreferences();
  }

  Future<void> _loadFromPrefs() async {
    // 1. Load local preferences first for instant UI response.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = NotificationPreferences.fromJson(json);
      } catch (_) {
        // Corrupted data -- keep defaults.
      }
    }

    // 2. Fetch from backend if authenticated and merge server data as the
    //    authoritative source (last-write-wins across devices).
    await _fetchFromBackend();
  }

  /// Fetch preferences from the backend and update local state if the
  /// response differs. Silently no-ops when offline or unauthenticated.
  Future<void> _fetchFromBackend() async {
    try {
      if (!ref.read(authStateProvider)) return;
      final api = ref.read(apiClientProvider);
      final data = await api.getNotificationPreferences();
      final serverPrefs = NotificationPreferences.fromJson(data);
      if (serverPrefs != state) {
        state = serverPrefs;
        // Persist the server-merged value locally.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
      }
    } catch (e) {
      // Backend fetch failed (offline, server error, etc.) -- keep local.
      debugPrint('[NotificationPreferences] backend fetch failed: $e');
    }
  }

  /// Push current preferences to the backend. Silently no-ops when offline
  /// or unauthenticated so that local preference changes always work.
  Future<void> _pushToBackend() async {
    try {
      if (!ref.read(authStateProvider)) return;
      final api = ref.read(apiClientProvider);
      await api.updateNotificationPreferences(
        state.toJson().map((k, v) => MapEntry(k, v as bool)),
      );
    } catch (e) {
      // Backend push failed (offline, server error, etc.) -- non-critical.
      debugPrint('[NotificationPreferences] backend push failed: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  /// Update individual preference fields and persist locally + push to backend.
  Future<void> update(NotificationPreferences prefs) async {
    state = prefs;
    await _saveToPrefs();
    await _pushToBackend();
  }

  /// Toggle a single preference by field name and persist locally + push to backend.
  Future<void> setField(String field, bool value) async {
    state = switch (field) {
      'reminderNotifications' => state.copyWith(reminderNotifications: value),
      'syncConflictNotifications' =>
        state.copyWith(syncConflictNotifications: value),
      'shareNotifications' => state.copyWith(shareNotifications: value),
      'pushNotifications' => state.copyWith(pushNotifications: value),
      _ => state,
    };
    await _saveToPrefs();
    await _pushToBackend();
  }
}

/// Provider for notification preferences. Watch this to reactively update UI.
final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);
