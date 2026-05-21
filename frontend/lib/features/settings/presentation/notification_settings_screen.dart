import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/notification_preferences.dart';

/// Settings screen for configuring notification preferences.
///
/// Displays grouped switch toggles for each notification channel:
/// reminders, sync conflicts, share events, and push notifications.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = Theme.of(context);
    final prefs = ref.watch(notificationPreferencesProvider);
    final isDark = l10n.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.s4,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          // ── Core notifications ─────────────────────────────
          const _SectionLabel(label: 'Notification Types'),
          const SizedBox(height: AppSpacing.s8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.smOf(Theme.of(context).brightness),
            ),
            child: Column(
              children: [
                _NotificationToggle(
                  icon: Icons.alarm_outlined,
                  title: 'Reminders',
                  subtitle: 'Get notified when a note reminder is due',
                  value: prefs.reminderNotifications,
                  accentBg: AppColors.accentLavenderBg,
                  accentText: AppColors.accentLavenderText,
                  onChanged: (value) {
                    ref
                        .read(notificationPreferencesProvider.notifier)
                        .setField('reminderNotifications', value);
                  },
                ),
                _Divider(isDark: isDark),
                _NotificationToggle(
                  icon: Icons.sync_problem_outlined,
                  title: 'Sync Conflicts',
                  subtitle: 'Alert when sync conflicts need resolution',
                  value: prefs.syncConflictNotifications,
                  accentBg: AppColors.accentYellowBg,
                  accentText: AppColors.accentYellowText,
                  onChanged: (value) {
                    ref
                        .read(notificationPreferencesProvider.notifier)
                        .setField('syncConflictNotifications', value);
                  },
                ),
                _Divider(isDark: isDark),
                _NotificationToggle(
                  icon: Icons.person_add_outlined,
                  title: 'Collaboration & Sharing',
                  subtitle: 'Notify when someone shares a note with you',
                  value: prefs.shareNotifications,
                  accentBg: AppColors.accentMintBg,
                  accentText: AppColors.accentMintText,
                  onChanged: (value) {
                    ref
                        .read(notificationPreferencesProvider.notifier)
                        .setField('shareNotifications', value);
                  },
                ),
                _Divider(isDark: isDark),
                _NotificationToggle(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications on your device',
                  value: prefs.pushNotifications,
                  accentBg: AppColors.accentPeachBg,
                  accentText: AppColors.accentPeachText,
                  onChanged: (value) {
                    ref
                        .read(notificationPreferencesProvider.notifier)
                        .setField('pushNotifications', value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Info note ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentLavenderBg.withAlpha(80),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.accentLavenderText,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Preferences are stored locally and sync across all your devices.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentLavenderText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary,
      ),
    );
  }
}

// ── Inline divider between toggles ─────────────────────────────

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Container(
        height: 0.5,
        color: isDark
            ? AppColors.darkDivider.withAlpha(40)
            : AppColors.lightDivider.withAlpha(60),
      ),
    );
  }
}

// ── Notification toggle row ────────────────────────────────────

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final Color accentBg;
  final Color accentText;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.accentBg,
    required this.accentText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value ? accentBg : AppColors.darkTextTertiary.withAlpha(8),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value
                  ? accentText
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
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
