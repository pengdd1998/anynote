import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';
import '../domain/notification_model.dart';

// ── Unread Count ────────────────────────────────────────

/// Fetches the unread notification count from the server.
final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final api = ref.read(apiClientProvider);
    final result = await api.getUnreadNotificationCount();
    return result['unread_count'] as int? ?? 0;
  } catch (e) {
    debugPrint('[Notifications] failed to fetch unread count: $e');
    return 0;
  }
});

// ── Notification List ───────────────────────────────────

/// Manages the paginated notification list.
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref _ref;
  static const _pageSize = 20;

  NotificationsNotifier(this._ref) : super(const NotificationsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const NotificationsState(isLoading: true);
    try {
      final api = _ref.read(apiClientProvider);
      final result = await api.getNotifications(limit: _pageSize, offset: 0);
      final list = (result['notifications'] as List?)
              ?.map((n) =>
                  AppNotification.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [];
      state = NotificationsState(notifications: list, hasMore: list.length >= _pageSize);
    } catch (e) {
      debugPrint('[Notifications] loadInitial failed: $e');
      state = NotificationsState(error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final offset = state.notifications.length;
      final api = _ref.read(apiClientProvider);
      final result = await api.getNotifications(
        limit: _pageSize,
        offset: offset,
      );
      final list = (result['notifications'] as List?)
              ?.map((n) =>
                  AppNotification.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [];
      state = state.copyWith(
        notifications: [...state.notifications, ...list],
        hasMore: list.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      debugPrint('[Notifications] loadMore failed: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.markNotificationRead(notificationId);
      final updated = state.notifications.map((n) {
        if (n.id == notificationId) return n.copyWith(isRead: true);
        return n;
      }).toList();
      state = state.copyWith(notifications: updated);
      _ref.invalidate(unreadCountProvider);
    } catch (e) {
      debugPrint('[Notifications] markAsRead failed: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final api = _ref.read(apiClientProvider);
      await api.markAllNotificationsRead();
      final updated =
          state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(notifications: updated);
      _ref.invalidate(unreadCountProvider);
    } catch (e) {
      debugPrint('[Notifications] markAllAsRead failed: $e');
    }
  }

  Future<void> refresh() async {
    await loadInitial();
    _ref.invalidate(unreadCountProvider);
  }
}

class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(ref),
);
