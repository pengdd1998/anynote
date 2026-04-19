import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/error/error.dart';
import '../../../core/export/export_service.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/notifications/push_service.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/settings_providers.dart';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsGroupHeader(title: l10n.account),
                  SettingsGroup(
                    children: [
                      accountAsync.when(
                        data: (account) => _accountItems(context, ref, account, l10n),
                        loading: () => _accountLoadingItems(l10n),
                        error: (_, __) => _accountErrorItems(l10n),
                      ),
                    ],
                  ),
                ],
              ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsGroupHeader(title: l10n.about),
                  SettingsGroup(
                    children: [
                      SettingsItem(
                        icon: Icons.info_outline,
                        title: l10n.version,
                        subtitle: '0.1.0',
                      ),
                      SettingsItem(
                        icon: Icons.privacy_tip_outlined,
                        title: l10n.privacyPolicy,
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {},
                      ),
                      SettingsItem(
                        icon: Icons.description_outlined,
                        title: l10n.termsOfService,
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // -- Sign out (destructive, in its own group) -----------------------
            StaggeredGroup(
              staggerIndex: 8,
              child: SettingsGroup(
                children: [
                  DestructiveSettingsItem(
                    icon: Icons.logout,
                    title: l10n.signOut,
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account section builders
  // ---------------------------------------------------------------------------

  /// Build the account items for the loaded state.
  Widget _accountItems(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> account,
    AppLocalizations l10n,
  ) {
    // The SettingsGroup expects a flat list of Widget children.
    // Since _accountItems is placed as a single child in the group,
    // return a Column that expands into the items.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsItem(
          icon: Icons.person_outline,
          title: l10n.email,
          subtitle: account['email'] as String? ?? 'Unknown',
        ),
        SettingsItem(
          icon: Icons.badge_outlined,
          title: l10n.plan,
          subtitle: account['plan'] as String? ?? 'Free',
          trailing: FilledButton.tonal(
            onPressed: () {},
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(l10n.upgrade),
          ),
        ),
      ],
    );
  }

  Widget _accountLoadingItems(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsItem(
          icon: Icons.person_outline,
          title: l10n.email,
          subtitle: l10n.loading,
        ),
        SettingsItem(
          icon: Icons.badge_outlined,
          title: l10n.plan,
          subtitle: l10n.loading,
        ),
      ],
    );
  }

  Widget _accountErrorItems(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsItem(
          icon: Icons.person_outline,
          title: l10n.email,
          subtitle: l10n.unableToLoadAccountInfo,
        ),
        SettingsItem(
          icon: Icons.badge_outlined,
          title: l10n.plan,
          subtitle: '--',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AI quota item
  // ---------------------------------------------------------------------------

  Widget _aiQuotaItem(AppLocalizations l10n, AsyncValue<Map<String, dynamic>> quotaAsync) {
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
      trailing: const _SyncButton(),
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
        String title = note.plainTitle ?? 'Untitled';
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

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutConfirmTitle),
        content: Text(l10n.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // Unregister device token from push notifications before clearing auth.
      await ref.read(pushNotificationServiceProvider).dispose();

      // Clear API client tokens (both in-memory and secure storage).
      final apiClient = ref.read(apiClientProvider);
      await apiClient.logout();

      // Clear the auth state so the router redirect sends us to login.
      ref.read(authStateProvider.notifier).state = false;

      // Navigate to login.
      if (context.mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signOutFailed(e.toString()))),
        );
      }
    }
  }
}

/// Separate widget for the sync button so it can use ConsumerStatefulWidget
/// to show a loading spinner during sync.
class _SyncButton extends ConsumerStatefulWidget {
  const _SyncButton();

  @override
  ConsumerState<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<_SyncButton> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isSyncing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return OutlinedButton(
      onPressed: _triggerSync,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(l10n.syncNow),
    );
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final notifier = ref.read(syncStatusProvider.notifier);
      final result = await notifier.sync();
      if (mounted) {
        final msg = result.hasConflicts
            ? l10n.syncCompleteWithConflicts(result.conflicts.length)
            : l10n.synced(result.pulledCount, result.pushedCount);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        ErrorDisplay.showSnackBar(context, appError, onRetry: _triggerSync);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }
}
