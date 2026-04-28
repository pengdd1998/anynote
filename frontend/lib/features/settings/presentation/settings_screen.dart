import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/animation_config.dart';
import '../../../core/theme/app_theme.dart';
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
      appBar: AppBar(title: Text(l10n.settings)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountInfoProvider);
          ref.invalidate(aiQuotaProvider);
          ref.invalidate(syncStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // -- Account section ------------------------------------------------
            StaggeredGroup(
              staggerIndex: 0,
              child: const _AccountSectionWidget(),
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
                          icon: Icons.smart_toy_outlined,
                          title: l10n.llmConfiguration,
                          subtitle: l10n.configureAIProviders,
                          trailing: const Icon(Icons.chevron_right, size: 20),
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
                          icon: Icons.share_outlined,
                          title: l10n.platformConnections,
                          subtitle: l10n.manageConnectedPlatforms,
                          trailing: const Icon(Icons.chevron_right, size: 20),
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
                          icon: Icons.shield_outlined,
                          title: l10n.encryptionSettings,
                          subtitle: l10n.e2eEncryptionActive,
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => context.push('/settings/security'),
                        ),
                        SettingsItem(
                          icon: Icons.label_outline,
                          title: l10n.manageTags,
                          trailing: const Icon(Icons.chevron_right, size: 20),
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
                    SettingsGroup(
                      children: [
                        const _SyncStatusSection(),
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
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Configure notification preferences',
                          trailing: const Icon(Icons.chevron_right, size: 20),
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
                          icon: Icons.file_upload_outlined,
                          title: l10n.importNotes,
                          subtitle: l10n.importNotesDesc,
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _showImportSheet(context),
                        ),
                        SettingsItem(
                          icon: Icons.file_download_outlined,
                          title: l10n.exportAllNotes,
                          subtitle: l10n.exportAllNotesDesc,
                          onTap: () => _showBatchExportDialog(context, ref),
                        ),
                        SettingsItem(
                          icon: Icons.restore_outlined,
                          title: l10n.restoreFromBackup,
                          subtitle: l10n.restoreFromBackupDesc,
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => context.push('/settings/restore'),
                        ),
                        SettingsItem(
                          icon: Icons.photo_library_outlined,
                          title: l10n.imageManagement,
                          subtitle: l10n.totalStorage,
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => context.push('/settings/images'),
                        ),
                        SettingsItem(
                          icon: Icons.description_outlined,
                          title: l10n.templateManagement,
                          subtitle: l10n.templates,
                          trailing: const Icon(Icons.chevron_right, size: 20),
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
                          icon: Icons.keyboard_outlined,
                          title: l10n.keyboardShortcuts,
                          trailing: const Icon(Icons.chevron_right, size: 20),
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
    // Show the new export sheet with ZIP and frontmatter options.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkBorder
                : AppTheme.lightBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _IconCircle(icon: icon),
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

/// Icon circle widget reused from settings item.
class _IconCircle extends StatelessWidget {
  final IconData icon;

  const _IconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: colorScheme.primary),
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
      icon: Icons.data_usage_outlined,
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
      icon: Icons.cloud_outlined,
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
                icon: Icons.language,
                title: l10n.language,
                subtitle: _getLanguageDisplayName(locale, l10n),
                trailing: const Icon(Icons.chevron_right, size: 20),
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
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: ListTile(
              leading: Icon(
                currentLocale.languageCode == 'en'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(l10n.english),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
              Navigator.pop(ctx);
            },
            child: ListTile(
              leading: Icon(
                currentLocale.languageCode == 'zh'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(l10n.chinese),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('ja'));
              Navigator.pop(ctx);
            },
            child: ListTile(
              leading: Icon(
                currentLocale.languageCode == 'ja'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(l10n.japanese),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('ko'));
              Navigator.pop(ctx);
            },
            child: ListTile(
              leading: Icon(
                currentLocale.languageCode == 'ko'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(l10n.korean),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
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
                icon: Icons.palette_outlined,
                title: l10n.theme,
                subtitle: _getThemeDisplayName(themeOption, l10n),
                trailing: const Icon(Icons.chevron_right, size: 20),
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
      ThemeOption option, AppLocalizations l10n) {
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

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          _buildThemeOption(
            context: ctx,
            option: ThemeOption.light,
            currentOption: currentOption,
            label: l10n.themeLight,
            ref: ref,
          ),
          _buildThemeOption(
            context: ctx,
            option: ThemeOption.dark,
            currentOption: currentOption,
            label: l10n.themeDark,
            ref: ref,
          ),
          _buildThemeOption(
            context: ctx,
            option: ThemeOption.system,
            currentOption: currentOption,
            label: l10n.themeSystem,
            ref: ref,
          ),
          const Divider(),
          _buildThemeOption(
            context: ctx,
            option: ThemeOption.highContrastLight,
            currentOption: currentOption,
            label: l10n.themeHighContrastLight,
            ref: ref,
            isHighContrast: true,
          ),
          _buildThemeOption(
            context: ctx,
            option: ThemeOption.highContrastDark,
            currentOption: currentOption,
            label: l10n.themeHighContrastDark,
            ref: ref,
            isHighContrast: true,
          ),
        ],
      ),
    );
  }

  static Widget _buildThemeOption({
    required BuildContext context,
    required ThemeOption option,
    required ThemeOption currentOption,
    required String label,
    required WidgetRef ref,
    bool isHighContrast = false,
  }) {
    final isSelected = currentOption == option;
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeOptionProvider.notifier).setThemeOption(option);
        Navigator.pop(context);
      },
      child: ListTile(
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: isHighContrast ? null : null,
        ),
        title: Text(
          label,
          style: isHighContrast
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
        ),
        contentPadding: EdgeInsets.zero,
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
          icon: Icons.animation_outlined,
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
