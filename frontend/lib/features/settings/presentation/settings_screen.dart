import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/platform/platform_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/animation_config.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../notes/presentation/widgets/export_sheet.dart';
import '../../notes/presentation/widgets/import_sheet.dart';
import '../../notifications/presentation/notification_badge.dart';
import '../data/settings_providers.dart';
import 'widgets/about_section.dart';
import 'widgets/account_section.dart';
import 'widgets/sign_out_section.dart';
import 'widgets/sync_section.dart';

/// Pastel accent pair used by settings row-cards: a soft tinted background
/// with a matching deep icon color (light), and a washed tint with a bright
/// icon color (dark).
class _TileAccent {
  final Color bg;
  final Color fg;
  final Color bright;

  const _TileAccent(this.bg, this.fg, this.bright);
}

/// Rotating pastel accents for settings icon tiles (lavender, peach, yellow,
/// mint, coral), matching the design mockup.
const _tileAccents = <_TileAccent>[
  _TileAccent(
    AppColors.accentLavenderBg,
    AppColors.accentLavenderText,
    AppColors.accentLavender,
  ),
  _TileAccent(
    AppColors.accentPeachBg,
    AppColors.accentPeachText,
    AppColors.accentPeach,
  ),
  _TileAccent(
    AppColors.accentYellowBg,
    AppColors.accentYellowText,
    AppColors.accentYellow,
  ),
  _TileAccent(
    AppColors.accentMintBg,
    AppColors.accentMintText,
    AppColors.accentMint,
  ),
  _TileAccent(
    AppColors.accentCoralBg,
    AppColors.accentCoralText,
    AppColors.accentCoral,
  ),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.settings,
              size: 18,
              color: isDark ? AppColors.secondary : AppColors.primaryText,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(l10n.settings),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const NotificationBadge(
              child: Icon(AppIcons.notificationsActive),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountInfoProvider);
          ref.invalidate(aiQuotaProvider);
          ref.invalidate(syncStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            // -- Account section ------------------------------------------------
            const StaggeredGroup(
              staggerIndex: 0,
              child: _AccountSectionWidget(),
            ),

            // -- AI section -----------------------------------------------------
            StaggeredGroup(
              staggerIndex: 1,
              child: Semantics(
                container: true,
                label: l10n.settingsGroup(l10n.aiSection),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsGroupHeader(title: l10n.aiSection),
                    _SettingsCardGroup(
                      children: [
                        _SettingsTile(
                          icon: AppIcons.aiRobot,
                          accent: _tileAccents[0],
                          title: l10n.llmConfiguration,
                          subtitle: l10n.configureAIProviders,
                          onTap: () => context.push('/settings/llm'),
                        ),
                        const _AiQuotaSection(),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // -- Publishing section ---------------------------------------------
            StaggeredGroup(
              staggerIndex: 2,
              child: Semantics(
                container: true,
                label: l10n.settingsGroup(l10n.publishing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsGroupHeader(title: l10n.publishing),
                    _SettingsCardGroup(
                      children: [
                        _SettingsTile(
                          icon: AppIcons.share,
                          accent: _tileAccents[2],
                          title: l10n.platformConnections,
                          subtitle: l10n.manageConnectedPlatforms,
                          onTap: () => context.push('/settings/platforms'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // -- Security section -----------------------------------------------
            StaggeredGroup(
              staggerIndex: 3,
              child: Semantics(
                container: true,
                label: l10n.settingsGroup(l10n.securityPrivacy),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsGroupHeader(title: l10n.securityPrivacy),
                    _SettingsCardGroup(
                      children: [
                        _SettingsTile(
                          icon: AppIcons.shield,
                          accent: _tileAccents[3],
                          title: l10n.encryptionSettings,
                          subtitle: l10n.e2eEncryptionActive,
                          onTap: () => context.push('/settings/security'),
                        ),
                        _SettingsTile(
                          icon: AppIcons.tag,
                          accent: _tileAccents[4],
                          title: l10n.manageTags,
                          subtitle: l10n.tagsLabel,
                          onTap: () => context.push('/tags'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // -- Sync section ---------------------------------------------------
            StaggeredGroup(
              staggerIndex: 4,
              child: Semantics(
                container: true,
                label: l10n.settingsGroup(l10n.sync),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsGroupHeader(title: l10n.sync),
                    const _SettingsCardGroup(
                      children: [
                        _SyncStatusSection(),
                      ],
                    ),
                    const SyncSection(),
                  ],
                ),
              ),
            ),

            // -- Notifications section ------------------------------------------
            StaggeredGroup(
              staggerIndex: 5,
              child: Semantics(
                container: true,
                label: l10n.settingsGroup('Notifications'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsGroupHeader(title: l10n.notifications),
                    _SettingsCardGroup(
                      children: [
                        _SettingsTile(
                          icon: AppIcons.notification,
                          accent: _tileAccents[1],
                          title: l10n.notifications,
                          subtitle: l10n.notificationPreferences,
                          onTap: () => context.push('/settings/notifications'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // -- Data section ---------------------------------------------------
            StaggeredGroup(
              staggerIndex: 6,
              child: Semantics(
                container: true,
                label: l10n.settingsGroup(l10n.data),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SettingsGroupHeader(title: l10n.data),
                    _SettingsCardGroup(
                      children: [
                        _SettingsTile(
                          icon: AppIcons.fileUpload,
                          accent: _tileAccents[2],
                          title: l10n.importNotes,
                          subtitle: l10n.importNotesDesc,
                          onTap: () => _showImportSheet(context),
                        ),
                        _SettingsTile(
                          icon: AppIcons.fileDownload,
                          accent: _tileAccents[3],
                          title: l10n.exportAllNotes,
                          subtitle: l10n.exportAllNotesDesc,
                          onTap: () => _showBatchExportDialog(context, ref),
                        ),
                        _SettingsTile(
                          icon: AppIcons.restore,
                          accent: _tileAccents[4],
                          title: l10n.restoreFromBackup,
                          subtitle: l10n.restoreFromBackupDesc,
                          onTap: () => context.push('/settings/restore'),
                        ),
                        _SettingsTile(
                          icon: AppIcons.photoLibrary,
                          accent: _tileAccents[0],
                          title: l10n.imageManagement,
                          subtitle: l10n.totalStorage,
                          onTap: () => context.push('/settings/images'),
                        ),
                        _SettingsTile(
                          icon: AppIcons.description,
                          accent: _tileAccents[1],
                          title: l10n.templateManagement,
                          subtitle: l10n.templates,
                          onTap: () => context.push('/settings/templates'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // -- Language section -----------------------------------------------
            const StaggeredGroup(
              staggerIndex: 7,
              child: _LanguageSection(),
            ),

            // -- Keyboard shortcuts section (desktop only — phones have no
            //    physical keyboard, the page is meaningless there) ------------
            if (PlatformUtils.isDesktop)
              StaggeredGroup(
                staggerIndex: 8,
                child: Semantics(
                  container: true,
                  label: l10n.settingsGroup(l10n.keyboardShortcuts),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsGroupHeader(title: l10n.keyboardShortcuts),
                      _SettingsCardGroup(
                        children: [
                          _SettingsTile(
                            icon: AppIcons.keyboard,
                            accent: _tileAccents[3],
                            title: l10n.keyboardShortcuts,
                            onTap: () => context.push('/settings/shortcuts'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // -- Appearance section ---------------------------------------------
            const StaggeredGroup(
              staggerIndex: 9,
              child: _AppearanceSection(),
            ),

            // -- About section --------------------------------------------------
            const StaggeredGroup(
              staggerIndex: 10,
              child: AboutSection(),
            ),

            // -- Sign out (destructive, in its own group) -----------------------
            const StaggeredGroup(
              staggerIndex: 11,
              child: SignOutSection(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBatchExportDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => const ExportSheet(
        scope: ExportScope.allNotes,
      ),
    );
  }

  void _showImportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => const ImportSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Local row-card components (design mockup: white cards, radius 16, 1px
// border, 40px pastel rounded-square icon tiles, ~12px spacing).
// ---------------------------------------------------------------------------

/// A vertical stack of individual row-cards separated by ~12px gaps.
class _SettingsCardGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: AppSpacing.s12),
          ],
        ],
      ),
    );
  }
}

/// A single settings row-card: 40px pastel rounded-square icon tile, title
/// (Inter w600 15), optional tertiary caption subtitle, and a trailing
/// chevron by default.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final _TileAccent accent;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            child: Row(
              children: [
                // 40px pastel rounded-square icon tile.
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? accent.fg.withAlpha(36) : accent.bg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isDark ? accent.bright : accent.fg,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
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
                              color: tertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(AppIcons.chevronRight, size: 18, color: tertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A settings row-card with an inline switch that doesn't navigate when tapped.
class _SettingsItemWithSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final _TileAccent accent;

  const _SettingsItemWithSwitch({
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? accent.fg.withAlpha(36) : accent.bg,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? accent.bright : accent.fg,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
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
            Semantics(
              hint: title,
              child: Switch(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extracted section widgets — each watches only the providers it needs,
// preventing rebuilds in sibling sections when an unrelated provider changes.
// ---------------------------------------------------------------------------

/// Account section — watches [accountInfoProvider] independently.
class _AccountSectionWidget extends ConsumerWidget {
  const _AccountSectionWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountInfoProvider);
    return AccountSection(accountAsync: accountAsync);
  }
}

/// AI quota item — watches [aiQuotaProvider] independently.
class _AiQuotaSection extends ConsumerWidget {
  const _AiQuotaSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final quotaAsync = ref.watch(aiQuotaProvider);
    return _SettingsTile(
      icon: AppIcons.dataUsage,
      accent: _tileAccents[1],
      title: l10n.aiQuota,
      subtitle: quotaAsync.when(
        data: (quota) {
          return l10n.requestsToday(quota.dailyUsed, quota.dailyLimit);
        },
        loading: () => l10n.loading,
        error: (_, __) => l10n.unableToLoadQuota,
      ),
    );
  }
}

/// Sync status item — watches [syncStatusProvider] independently.
class _SyncStatusSection extends ConsumerWidget {
  const _SyncStatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final syncStatusAsync = ref.watch(syncStatusProvider);
    return _SettingsTile(
      icon: AppIcons.cloud,
      accent: _tileAccents[0],
      title: l10n.syncStatus,
      subtitle: syncStatusAsync.when(
        data: (status) {
          final lastSynced = status.lastSyncedAt;
          if (lastSynced == null) {
            return l10n.lastSyncedNever;
          }
          return l10n.lastSynced(_formatSyncTime(lastSynced, l10n));
        },
        loading: () => l10n.checking,
        error: (_, __) => l10n.unableToLoadSyncStatus,
      ),
      trailing: const SyncButton(),
    );
  }

  static String _formatSyncTime(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Language section — watches [localeProvider] independently.
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    return Semantics(
      container: true,
      label: l10n.settingsGroup(l10n.language),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsGroupHeader(title: l10n.language),
          _SettingsCardGroup(
            children: [
              _SettingsTile(
                icon: AppIcons.language,
                accent: _tileAccents[2],
                title: l10n.language,
                subtitle: _getLanguageDisplayName(locale, l10n),
                onTap: () => _showLanguageDialog(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _getLanguageDisplayName(Locale locale, AppLocalizations l10n) {
    return switch (locale.languageCode) {
      'zh' => l10n.chinese,
      'ja' => l10n.japanese,
      'ko' => l10n.korean,
      _ => l10n.english,
    };
  }

  static void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.read(localeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.language),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              label: l10n.english,
              isSelected: currentLocale.languageCode == 'en',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentPeachBg,
              accentText: AppColors.accentPeachText,
            ),
            _LanguageOption(
              label: l10n.chinese,
              isSelected: currentLocale.languageCode == 'zh',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentYellowBg,
              accentText: AppColors.accentYellowText,
            ),
            _LanguageOption(
              label: l10n.japanese,
              isSelected: currentLocale.languageCode == 'ja',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('ja'));
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentMintBg,
              accentText: AppColors.accentMintText,
            ),
            _LanguageOption(
              label: l10n.korean,
              isSelected: currentLocale.languageCode == 'ko',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('ko'));
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentPeachBg,
              accentText: AppColors.accentPeachText,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single language option row with radio indicator and accent color.
class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentBg;
  final Color accentText;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentBg,
    required this.accentText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? accentBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? accentText.withAlpha(20)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? accentText
                        : AppColors.darkTextTertiary.withAlpha(60),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentText,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Appearance section — watches [themeOptionProvider] and
/// [reduceMotionOverrideProvider] independently.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeOption = ref.watch(themeOptionProvider);
    return Semantics(
      container: true,
      label: l10n.settingsGroup(l10n.appearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsGroupHeader(title: l10n.appearance),
          _SettingsCardGroup(
            children: [
              _SettingsTile(
                icon: AppIcons.palette,
                accent: _tileAccents[4],
                title: l10n.theme,
                subtitle: _getThemeDisplayName(themeOption, l10n),
                onTap: () => _showThemeDialog(context, ref),
              ),
              _ReduceMotionItem(l10n: l10n),
            ],
          ),
        ],
      ),
    );
  }

  static String _getThemeDisplayName(
    ThemeOption option,
    AppLocalizations l10n,
  ) {
    return switch (option) {
      ThemeOption.light => l10n.themeLight,
      ThemeOption.dark => l10n.themeDark,
      ThemeOption.system => l10n.themeSystem,
      ThemeOption.highContrastLight => l10n.themeHighContrastLight,
      ThemeOption.highContrastDark => l10n.themeHighContrastDark,
    };
  }

  static void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentOption = ref.read(themeOptionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.theme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              label: l10n.themeLight,
              icon: Icons.light_mode_outlined,
              isSelected: currentOption == ThemeOption.light,
              onTap: () {
                ref
                    .read(themeOptionProvider.notifier)
                    .setThemeOption(ThemeOption.light);
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentYellowBg,
              accentText: AppColors.accentYellowText,
            ),
            _ThemeOption(
              label: l10n.themeDark,
              icon: Icons.dark_mode_outlined,
              isSelected: currentOption == ThemeOption.dark,
              onTap: () {
                ref
                    .read(themeOptionProvider.notifier)
                    .setThemeOption(ThemeOption.dark);
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentPeachBg,
              accentText: AppColors.accentPeachText,
            ),
            _ThemeOption(
              label: l10n.themeSystem,
              icon: Icons.settings_suggest_outlined,
              isSelected: currentOption == ThemeOption.system,
              onTap: () {
                ref
                    .read(themeOptionProvider.notifier)
                    .setThemeOption(ThemeOption.system);
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentMintBg,
              accentText: AppColors.accentMintText,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Divider(
                height: 1,
                color: isDark
                    ? AppColors.darkDivider.withAlpha(60)
                    : AppColors.lightDivider.withAlpha(80),
              ),
            ),
            _ThemeOption(
              label: l10n.themeHighContrastLight,
              icon: Icons.contrast_outlined,
              isSelected: currentOption == ThemeOption.highContrastLight,
              onTap: () {
                ref
                    .read(themeOptionProvider.notifier)
                    .setThemeOption(ThemeOption.highContrastLight);
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentPeachBg,
              accentText: AppColors.accentPeachText,
              isHighContrast: true,
            ),
            _ThemeOption(
              label: l10n.themeHighContrastDark,
              icon: Icons.contrast,
              isSelected: currentOption == ThemeOption.highContrastDark,
              onTap: () {
                ref
                    .read(themeOptionProvider.notifier)
                    .setThemeOption(ThemeOption.highContrastDark);
                Navigator.pop(ctx);
              },
              accentBg: AppColors.accentPeachBg,
              accentText: AppColors.accentPeachText,
              isHighContrast: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single theme option row with radio indicator and icon.
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentBg;
  final Color accentText;
  final bool isHighContrast;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.accentBg,
    required this.accentText,
    this.isHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? accentBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentText.withAlpha(20)
                      : AppColors.darkTextTertiary.withAlpha(8),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? accentText
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: isHighContrast
                        ? FontWeight.bold
                        : (isSelected ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, size: 20, color: accentText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reduce-motion toggle — watches [reduceMotionOverrideProvider] independently.
class _ReduceMotionItem extends ConsumerWidget {
  final AppLocalizations l10n;

  const _ReduceMotionItem({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(reduceMotionOverrideProvider);
    return Builder(
      builder: (context) {
        final systemDisabled = MediaQuery.disableAnimationsOf(context);
        final isEnabled = override ?? systemDisabled;

        return _SettingsItemWithSwitch(
          icon: AppIcons.animation,
          accent: _tileAccents[0],
          title: l10n.reduceMotion,
          subtitle: override == null
              ? l10n.reduceMotionSystem
              : isEnabled
                  ? l10n.reduceMotionOn
                  : l10n.reduceMotionOff,
          value: isEnabled,
          onChanged: (value) {
            ref.read(reduceMotionOverrideProvider.notifier).state = value;
          },
        );
      },
    );
  }
}
