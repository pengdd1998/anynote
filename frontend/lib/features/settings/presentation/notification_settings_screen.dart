import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../data/notification_preferences.dart';

/// Settings screen for configuring notification preferences.
///
/// Displays grouped switch toggles for each notification channel:
/// reminders, sync conflicts, share events, and push notifications.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(notificationPreferencesProvider);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        centerTitle: true,
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
          // ── General ─────────────────────────────────────────
          _SectionLabel(label: l10n.general),
          const SizedBox(height: AppSpacing.s8),
          _NotificationToggle(
            icon: Icons.sync_problem_outlined,
            title: l10n.syncConflicts,
            subtitle: l10n.syncConflictNotificationsDesc,
            value: prefs.syncConflictNotifications,
            accentBg: isDark
                ? AppColors.accentYellowText.withAlpha(36)
                : AppColors.accentYellowBg,
            accentIcon:
                isDark ? AppColors.accentYellow : AppColors.accentYellowText,
            onChanged: (value) {
              ref
                  .read(notificationPreferencesProvider.notifier)
                  .setField('syncConflictNotifications', value);
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          _NotificationToggle(
            icon: Icons.person_add_outlined,
            title: l10n.collaborationSharing,
            subtitle: l10n.shareNotificationsDesc,
            value: prefs.shareNotifications,
            accentBg: isDark
                ? AppColors.accentMintText.withAlpha(36)
                : AppColors.accentMintBg,
            accentIcon:
                isDark ? AppColors.accentMint : AppColors.accentMintText,
            onChanged: (value) {
              ref
                  .read(notificationPreferencesProvider.notifier)
                  .setField('shareNotifications', value);
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          _NotificationToggle(
            icon: Icons.notifications_active_outlined,
            title: l10n.pushNotifications,
            subtitle: l10n.pushNotificationsDesc,
            value: prefs.pushNotifications,
            accentBg: isDark
                ? AppColors.accentPeachText.withAlpha(36)
                : AppColors.accentPeachBg,
            accentIcon:
                isDark ? AppColors.accentPeach : AppColors.accentPeachText,
            onChanged: (value) {
              ref
                  .read(notificationPreferencesProvider.notifier)
                  .setField('pushNotifications', value);
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Reminders ───────────────────────────────────────
          _SectionLabel(label: l10n.reminders),
          const SizedBox(height: AppSpacing.s8),
          _NotificationToggle(
            icon: Icons.alarm_outlined,
            title: l10n.reminders,
            subtitle: l10n.reminderNotificationsDesc,
            value: prefs.reminderNotifications,
            accentBg: isDark
                ? AppColors.accentPeachText.withAlpha(36)
                : AppColors.accentPeachBg,
            accentIcon:
                isDark ? AppColors.accentPeach : AppColors.accentPeachText,
            onChanged: (value) {
              ref
                  .read(notificationPreferencesProvider.notifier)
                  .setField('reminderNotifications', value);
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Info note ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: AppColors.accentPeachBg.withAlpha(80),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.accentPeachText,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    l10n.notificationPrefsLocalNote,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentPeachText,
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
        color:
            isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
      ),
    );
  }
}

// ── Notification toggle row-card ───────────────────────────────

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final Color accentBg;
  final Color accentIcon;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.accentBg,
    required this.accentIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? accentBg
                  : (isDark
                      ? AppColors.darkTextTertiary.withAlpha(12)
                      : AppColors.lightInputFill),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value
                  ? accentIcon
                  : (isDark
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
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
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
