import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_provider.dart';
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
import '../data/settings_providers.dart';
import 'widgets/about_section.dart';
import 'widgets/account_section.dart';
import 'widgets/sign_out_section.dart';
import 'widgets/sync_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    SettingsGroup(
                      children: [
                        SettingsItem(
                          icon: AppIcons.aiRobot,
                          title: l10n.llmConfiguration,
                          subtitle: l10n.configureAIProviders,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
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
                    SettingsGroup(
                      children: [
                        SettingsItem(
                          icon: AppIcons.share,
                          title: l10n.platformConnections,
                          subtitle: l10n.manageConnectedPlatforms,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
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
                    SettingsGroup(
                      children: [
                        SettingsItem(
                          icon: AppIcons.shield,
                          title: l10n.encryptionSettings,
                          subtitle: l10n.e2eEncryptionActive,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
                          onTap: () => context.push('/settings/security'),
                        ),
                        SettingsItem(
                          icon: AppIcons.tag,
                          title: l10n.manageTags,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
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
                    const SettingsGroup(
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
                    const SettingsGroupHeader(title: 'Notifications'),
                    SettingsGroup(
                      children: [
                        SettingsItem(
                          icon: AppIcons.notification,
                          title: 'Notifications',
                          subtitle: 'Configure notification preferences',
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
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
                    SettingsGroup(
                      children: [
                        SettingsItem(
                          icon: AppIcons.fileUpload,
                          title: l10n.importNotes,
                          subtitle: l10n.importNotesDesc,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
                          onTap: () => _showImportSheet(context),
                        ),
                        SettingsItem(
                          icon: AppIcons.fileDownload,
                          title: l10n.exportAllNotes,
                          subtitle: l10n.exportAllNotesDesc,
                          onTap: () => _showBatchExportDialog(context, ref),
                        ),
                        SettingsItem(
                          icon: AppIcons.restore,
                          title: l10n.restoreFromBackup,
                          subtitle: l10n.restoreFromBackupDesc,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
                          onTap: () => context.push('/settings/restore'),
                        ),
                        SettingsItem(
                          icon: AppIcons.photoLibrary,
                          title: l10n.imageManagement,
                          subtitle: l10n.totalStorage,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
                          onTap: () => context.push('/settings/images'),
                        ),
                        SettingsItem(
                          icon: AppIcons.description,
                          title: l10n.templateManagement,
                          subtitle: l10n.templates,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
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

            // -- Keyboard shortcuts section -------------------------------------
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
                    SettingsGroup(
                      children: [
                        SettingsItem(
                          icon: AppIcons.keyboard,
                          title: l10n.keyboardShortcuts,
                          trailing: const Icon(AppIcons.chevronRight, size: 20),
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

/// A settings item with an inline switch that doesn't navigate when tapped.
class _SettingsItemWithSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsItemWithSwitch({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              IconCircle(icon: icon),
              const SizedBox(width: AppSpacing.s12),
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
    return SettingsItem(
      icon: AppIcons.dataUsage,
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
    return SettingsItem(
      icon: AppIcons.cloud,
      title: l10n.syncStatus,
      subtitle: syncStatusAsync.when(
        data: (status) {
          final lastSynced = status.lastSyncedAt;
          if (lastSynced == null) {
            return l10n.lastSyncedNever;
          }
          return l10n.lastSynced(lastSynced.toIso8601String());
        },
        loading: () => l10n.checking,
        error: (_, __) => l10n.unableToLoadSyncStatus,
      ),
      trailing: const SyncButton(),
    );
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
          SettingsGroup(
            children: [
              SettingsItem(
                icon: AppIcons.language,
                title: l10n.language,
                subtitle: _getLanguageDisplayName(locale, l10n),
                trailing: const Icon(AppIcons.chevronRight, size: 20),
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
              accentBg: AppColors.accentLavenderBg,
              accentText: AppColors.accentLavenderText,
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
          SettingsGroup(
            children: [
              SettingsItem(
                icon: AppIcons.palette,
                title: l10n.theme,
                subtitle: _getThemeDisplayName(themeOption, l10n),
                trailing: const Icon(AppIcons.chevronRight, size: 20),
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
              accentBg: AppColors.accentLavenderBg,
              accentText: AppColors.accentLavenderText,
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
