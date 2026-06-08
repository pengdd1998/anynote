import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notification_providers.dart';
import '../domain/notification_model.dart';

/// Screen displaying the user's notification list with unread badges.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.notifications ?? 'Notifications'),
        actions: [
          if (state.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: Text(l10n?.markAllRead ?? 'Mark all read'),
            ),
        ],
      ),
      body: _buildBody(context, ref, state, l10n, theme, colorScheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
    AppLocalizations? l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n?.failedToLoadNotifications ?? 'Failed to load notifications',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.s12),
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: Text(l10n?.retry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              l10n?.noNotifications ?? 'No notifications',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        itemCount:
            state.notifications.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.notifications.length) {
            // Load more trigger.
            ref.read(notificationsProvider.notifier).loadMore();
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.s16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _NotificationTile(
            notification: state.notifications[index],
            onTap: () {
              final n = state.notifications[index];
              if (!n.isRead) {
                ref
                    .read(notificationsProvider.notifier)
                    .markAsRead(n.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: notification.isRead
              ? colorScheme.surfaceContainerHighest
              : colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          _iconForType(notification.type),
          size: 20,
          color: notification.isRead
              ? colorScheme.onSurfaceVariant
              : colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: notification.body.isNotEmpty
          ? Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: !notification.isRead
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'sync_conflict' => Icons.sync_problem,
      'share' => Icons.share,
      'comment' => Icons.comment,
      'collab' => Icons.people,
      'reminder' => Icons.notifications_active,
      'plan' => Icons.card_membership,
      _ => Icons.notifications,
    };
  }
}
