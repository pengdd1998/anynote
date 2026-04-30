import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_components.dart';
import '../data/notification_preferences.dart';

/// Settings screen for configuring notification preferences.
///
/// Displays a list of switch toggles for each notification channel:
/// reminders, sync conflicts, share events, and push notifications.
/// Uses the shared [SettingsGroup] / [SettingsGroupHeader] components
/// for visual consistency with the main settings screen.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SettingsGroupHeader(title: 'Notification Types'),
          SettingsGroup(
            children: [
              _NotificationSwitchTile(
                icon: AppIcons.alarm,
                title: 'Reminders',
                subtitle: 'Get notified when a note reminder is due',
                value: prefs.reminderNotifications,
                onChanged: (value) {
                  ref
                      .read(notificationPreferencesProvider.notifier)
                      .setField('reminderNotifications', value);
                },
              ),
              _NotificationSwitchTile(
                icon: AppIcons.syncProblem,
                title: 'Sync Conflicts',
                subtitle: 'Alert when sync conflicts need resolution',
                value: prefs.syncConflictNotifications,
                onChanged: (value) {
                  ref
                      .read(notificationPreferencesProvider.notifier)
                      .setField('syncConflictNotifications', value);
                },
              ),
              _NotificationSwitchTile(
                icon: AppIcons.personAdd,
                title: 'Collaboration & Sharing',
                subtitle: 'Notify when someone shares a note with you',
                value: prefs.shareNotifications,
                onChanged: (value) {
                  ref
                      .read(notificationPreferencesProvider.notifier)
                      .setField('shareNotifications', value);
                },
              ),
              _NotificationSwitchTile(
                icon: AppIcons.notificationsActive,
                title: 'Push Notifications',
                subtitle: 'Receive push notifications on your device',
                value: prefs.pushNotifications,
                onChanged: (value) {
                  ref
                      .read(notificationPreferencesProvider.notifier)
                      .setField('pushNotifications', value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Notification preferences are stored locally and apply across all your devices.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row with an inline switch toggle for a notification channel.
///
/// Follows the visual pattern of [SettingsItem] but uses [SwitchListTile]
/// for inline toggle behavior instead of navigation.
class _NotificationSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Icon circle matching SettingsItem style.
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            hint: title,
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
