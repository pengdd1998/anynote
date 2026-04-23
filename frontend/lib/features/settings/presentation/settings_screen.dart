import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/export/export_service.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/settings_providers.dart';
import 'widgets/about_section.dart';
import 'widgets/account_section.dart';
import 'widgets/sign_out_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountAsync = ref.watch(accountInfoProvider);
    final aiQuotaAsync = ref.watch(aiQuotaProvider);
    final syncStatusAsync = ref.watch(syncStatusProvider);

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
              child: AccountSection(accountAsync: accountAsync),
            ),

            // -- AI section -----------------------------------------------------
            StaggeredGroup(
              staggerIndex: 1,
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
                      _aiQuotaItem(l10n, aiQuotaAsync),
                    ],
                  ),
                ],
              ),
            ),

            // -- Publishing section ---------------------------------------------
            StaggeredGroup(
              staggerIndex: 2,
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

            // -- Security section -----------------------------------------------
            StaggeredGroup(
              staggerIndex: 3,
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

            // -- Sync section ---------------------------------------------------
            StaggeredGroup(
              staggerIndex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsGroupHeader(title: l10n.sync),
                  SettingsGroup(
                    children: [
                      _syncStatusItem(l10n, syncStatusAsync),
                    ],
                  ),
                ],
              ),
            ),

            // -- Data section ---------------------------------------------------
            StaggeredGroup(
              staggerIndex: 5,
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
                        onTap: () => context.push('/settings/import'),
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
                    ],
                  ),
                ],
              ),
            ),

            // -- Language section -----------------------------------------------
            StaggeredGroup(
              staggerIndex: 6,
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
                        subtitle: _getLanguageDisplayName(
                          ref.watch(localeProvider),
                          l10n,
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _showLanguageDialog(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // -- About section --------------------------------------------------
            StaggeredGroup(
              staggerIndex: 7,
              child: const AboutSection(),
            ),

            // -- Sign out (destructive, in its own group) -----------------------
            StaggeredGroup(
              staggerIndex: 8,
              child: const SignOutSection(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AI quota item
  // ---------------------------------------------------------------------------

  Widget _aiQuotaItem(
    AppLocalizations l10n,
    AsyncValue<Map<String, dynamic>> quotaAsync,
  ) {
    return SettingsItem(
      icon: Icons.data_usage_outlined,
      title: l10n.aiQuota,
      subtitle: quotaAsync.when(
        data: (quota) {
          final used = quota['used'] ?? 0;
          final limit = quota['limit'] ?? 50;
          return l10n.requestsToday(used as int, limit as int);
        },
        loading: () => l10n.loading,
        error: (_, __) => l10n.unableToLoadQuota,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sync status item
  // ---------------------------------------------------------------------------

  Widget _syncStatusItem(
    AppLocalizations l10n,
    AsyncValue<Map<String, dynamic>> syncStatusAsync,
  ) {
    return SettingsItem(
      icon: Icons.cloud_outlined,
      title: l10n.syncStatus,
      subtitle: syncStatusAsync.when(
        data: (status) {
          final lastSyncedAt = status['last_synced_at'] as String?;
          if (lastSyncedAt == null || lastSyncedAt.isEmpty) {
            return l10n.lastSyncedNever;
          }
          return l10n.lastSynced(lastSyncedAt);
        },
        loading: () => l10n.checking,
        error: (_, __) => l10n.unableToLoadSyncStatus,
      ),
      trailing: const SyncButton(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _getLanguageDisplayName(Locale locale, AppLocalizations l10n) {
    return switch (locale.languageCode) {
      'zh' => l10n.chinese,
      'ja' => l10n.japanese,
      'ko' => l10n.korean,
      _ => l10n.english,
    };
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
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

  Future<void> _showBatchExportDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.exportAllNotes),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ExportFormat.markdown),
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.markdownFormat),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ExportFormat.html),
            child: ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.htmlFormat),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ExportFormat.plainText),
            child: ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: Text(l10n.plainTextFormat),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

    if (format == null || !context.mounted) return;

    // Show a loading indicator.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final notes = await db.notesDao.getAllNotes();

      if (notes.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noNotesToExport)),
          );
        }
        return;
      }

      // Decrypt notes that have encrypted content.
      final decrypted = <({String title, String content, String id})>[];
      for (final note in notes) {
        String title = note.plainTitle ?? l10n.untitled;
        String content = note.plainContent ?? '';

        if (crypto.isUnlocked) {
          final decryptedContent =
              await crypto.decryptForItem(note.id, note.encryptedContent);
          if (decryptedContent != null) {
            content = decryptedContent;
          }
          if (note.encryptedTitle != null) {
            final decryptedTitle =
                await crypto.decryptForItem(note.id, note.encryptedTitle!);
            if (decryptedTitle != null) {
              title = decryptedTitle;
            }
          }
        }

        // Skip notes that have no usable content.
        if (content.trim().isEmpty) continue;

        decrypted.add((title: title, content: content, id: note.id));
      }

      if (decrypted.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context); // dismiss loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.noNotesWithContent)),
          );
        }
        return;
      }

      final file = await ExportService.exportBatch(decrypted, format);

      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        await ExportService.shareFile(file);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }
}
