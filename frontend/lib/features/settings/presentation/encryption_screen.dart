import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/settings_providers.dart';

class EncryptionScreen extends ConsumerStatefulWidget {
  const EncryptionScreen({super.key});

  @override
  ConsumerState<EncryptionScreen> createState() => _EncryptionScreenState();
}

class _EncryptionScreenState extends ConsumerState<EncryptionScreen> {
  bool _showRecoveryKey = false;
  bool _isChangingPassword = false;
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final encryptionStatus = ref.watch(encryptionStatusProvider);
    final countsAsync = ref.watch(localItemCountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityEncryption)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          StaggeredGroup(
            staggerIndex: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _StatusCard(
                isActive: encryptionStatus.isInitialized,
                isUnlocked: encryptionStatus.isUnlocked,
                colorScheme: colorScheme,
                l10n: l10n,
              ),
            ),
          ),
          StaggeredGroup(
            staggerIndex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _CrossPlatformWarningCard(l10n: l10n),
            ),
          ),

          // -- Encrypted items -------------------------------------------------
          StaggeredGroup(
            staggerIndex: 2,
            child: _EncryptedItemsGroup(
              countsAsync: countsAsync,
              l10n: l10n,
            ),
          ),

          // -- Recovery key ----------------------------------------------------
          StaggeredGroup(
            staggerIndex: 3,
            child: _RecoveryKeySection(
              l10n: l10n,
              theme: theme,
              showRecoveryKey: _showRecoveryKey,
              onVerifyAndShow: _verifyAndShowRecoveryKey,
              onHideRecoveryKey: () => setState(() => _showRecoveryKey = false),
            ),
          ),

          // -- Password & key management ---------------------------------------
          StaggeredGroup(
            staggerIndex: 4,
            child: _PasswordManagementSection(
              l10n: l10n,
              isChangingPassword: _isChangingPassword,
              onChangePassword: _showChangePasswordDialog,
            ),
          ),

          // -- Danger zone -----------------------------------------------------
          StaggeredGroup(
            staggerIndex: 5,
            child: _DangerZoneSection(
              isDeleting: _isDeleting,
              onDeleteAll: _confirmDeleteAll,
              onExportBackup: _exportBackup,
              onImportBackup: _importBackup,
              l10n: l10n,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  /// Verify the user's password before showing the recovery key.
  void _verifyAndShowRecoveryKey() {
    final l10n = AppLocalizations.of(context)!;
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.verifyPassword),
        content: TextField(
          controller: passwordCtrl,
          decoration: InputDecoration(labelText: l10n.enterYourPassword),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                final crypto = ref.read(cryptoServiceProvider);
                final verified =
                    await crypto.unlockWithPassword(passwordCtrl.text);
                nav.pop();
                if (verified) {
                  setState(() => _showRecoveryKey = true);
                } else {
                  if (mounted) {
                    AppSnackBar.error(context, message: l10n.incorrectPassword);
                  }
                }
              } catch (e) {
                debugPrint(
                    '[EncryptionScreen] password verification failed: $e');
                nav.pop();
                if (mounted) {
                  AppSnackBar.error(context, message: l10n.verificationFailed);
                }
              }
            },
            child: Text(l10n.verify),
          ),
        ],
      ),
    );
  }

  /// Show the change password dialog with actual re-encryption logic.
  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.changePassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              decoration: InputDecoration(
                labelText: l10n.currentPassword,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              decoration: InputDecoration(labelText: l10n.newPassword),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: InputDecoration(
                labelText: l10n.confirmNewPassword,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reEncryptWarning,
              style: TextStyle(
                fontSize: 12,
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                AppSnackBar.error(context, message: l10n.passwordsDoNotMatch);
                return;
              }
              if (newCtrl.text.length < 8) {
                AppSnackBar.error(context, message: l10n.passwordMinLength);
                return;
              }

              final nav = Navigator.of(ctx);
              setState(() => _isChangingPassword = true);

              try {
                final crypto = ref.read(cryptoServiceProvider);

                // Verify current password by attempting unlock.
                final verified =
                    await crypto.unlockWithPassword(currentCtrl.text);
                if (!verified) {
                  nav.pop();
                  if (mounted) {
                    AppSnackBar.error(context,
                        message: l10n.currentPasswordIncorrect);
                  }
                  return;
                }

                // Re-initialize encryption with the new password.
                await crypto.initialize(newCtrl.text);

                nav.pop();
                if (mounted) {
                  // Refresh the encryption status.
                  ref.read(encryptionStatusProvider.notifier).refresh();
                  AppSnackBar.info(context,
                      message: l10n.passwordChangedSuccessfully);
                }
              } catch (e) {
                nav.pop();
                if (mounted) {
                  AppSnackBar.error(context,
                      message: l10n.failedToChangePassword(e.toString()));
                }
              } finally {
                if (mounted) {
                  setState(() => _isChangingPassword = false);
                }
              }
            },
            child: Text(l10n.change),
          ),
        ],
      ),
    );
  }

  /// Confirm and delete all local data.
  void _confirmDeleteAll() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAllDataQuestion),
        content: Text(l10n.deleteAllDataMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Double confirm with typed confirmation.
              _doubleConfirmDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.deleteEverything),
          ),
        ],
      ),
    );
  }

  /// Second confirmation: user must type DELETE to proceed.
  void _doubleConfirmDelete() {
    final l10n = AppLocalizations.of(context)!;
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.areYouAbsolutelySure),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.typeDeleteToConfirm),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: InputDecoration(
                labelText: l10n.typeDelete,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              if (confirmCtrl.text != 'DELETE') {
                return;
              }

              final nav = Navigator.of(ctx);
              setState(() => _isDeleting = true);
              try {
                // Clear all encryption keys.
                final crypto = ref.read(cryptoServiceProvider);
                await crypto.clearAll();

                // Clear all database tables.
                final db = ref.read(databaseProvider);
                await db.customStatement('DELETE FROM notes');
                await db.customStatement('DELETE FROM notes_fts');
                await db.customStatement('DELETE FROM tags');
                await db.customStatement('DELETE FROM note_tags');
                await db.customStatement('DELETE FROM collections');
                await db.customStatement(
                  'DELETE FROM collection_notes',
                );
                await db.customStatement('DELETE FROM generated_contents');
                await db.customStatement('DELETE FROM sync_meta');

                nav.pop();

                if (mounted) {
                  ref.read(encryptionStatusProvider.notifier).refresh();
                  ref.invalidate(localItemCountsProvider);
                  AppSnackBar.info(context, message: l10n.allLocalDataDeleted);
                }
              } catch (e) {
                nav.pop();
                if (mounted) {
                  AppSnackBar.error(context,
                      message: l10n.failedToDeleteData(e.toString()));
                }
              } finally {
                if (mounted) setState(() => _isDeleting = false);
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  /// Export an encrypted backup of all local data.
  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context)!;

    // File system APIs are not available on web platform.
    if (kIsWeb) {
      if (mounted) {
        AppSnackBar.error(context, message: l10n.notSupportedOnWeb);
      }
      return;
    }

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final backupService = BackupService(db, crypto);

      final backupData = await backupService.exportBackup();

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final fileName = 'anynote-backup-$timestamp.enc';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(backupData);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'AnyNote encrypted backup',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context,
            message: l10n.backupExportFailed(e.toString()));
      }
    }
  }

  /// Import data from an encrypted backup file.
  Future<void> _importBackup() async {
    final l10n = AppLocalizations.of(context)!;

    // File system APIs are not available on web platform.
    if (kIsWeb) {
      if (mounted) {
        AppSnackBar.error(context, message: l10n.notSupportedOnWeb);
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['enc'],
      );
      if (result == null) return;

      final file = File(result.files.single.path!);
      final data = await file.readAsBytes();

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.importBackup),
          content: Text(l10n.importBackupMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.import),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final backupService = BackupService(db, crypto);

      final count = await backupService.importBackup(data);

      if (mounted) {
        ref.invalidate(localItemCountsProvider);
        AppSnackBar.info(context, message: l10n.importedItemsFromBackup(count));
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context,
            message: l10n.backupImportFailed(e.toString()));
      }
    }
  }
}

// =============================================================================
// Encrypted items group
// =============================================================================

/// Displays a list of encrypted item counts grouped under a header.
class _EncryptedItemsGroup extends StatelessWidget {
  final AsyncValue<Map<String, int>> countsAsync;
  final AppLocalizations l10n;

  const _EncryptedItemsGroup({
    required this.countsAsync,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroupHeader(title: l10n.encryptedItems),
        SettingsGroup(
          children: [
            countsAsync.when(
              data: (counts) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsItem(
                    icon: Icons.note_outlined,
                    title: l10n.notes,
                    subtitle: l10n.itemsCount(counts['notes'] ?? 0),
                  ),
                  SettingsItem(
                    icon: Icons.label_outline,
                    title: l10n.tagsLabel,
                    subtitle: l10n.itemsCount(counts['tags'] ?? 0),
                  ),
                  SettingsItem(
                    icon: Icons.folder_outlined,
                    title: l10n.collectionsLabel,
                    subtitle: l10n.itemsCount(counts['collections'] ?? 0),
                  ),
                  SettingsItem(
                    icon: Icons.auto_awesome_outlined,
                    title: l10n.aiContent,
                    subtitle: l10n.itemsCount(counts['ai_content'] ?? 0),
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SettingsItem(
                    icon: Icons.note_outlined,
                    title: l10n.notes,
                    subtitle: '--',
                  ),
                  SettingsItem(
                    icon: Icons.label_outline,
                    title: l10n.tagsLabel,
                    subtitle: '--',
                  ),
                  SettingsItem(
                    icon: Icons.folder_outlined,
                    title: l10n.collectionsLabel,
                    subtitle: '--',
                  ),
                  SettingsItem(
                    icon: Icons.auto_awesome_outlined,
                    title: l10n.aiContent,
                    subtitle: '--',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Recovery key section
// =============================================================================

/// Displays the recovery key section with a verify/show button and key display.
class _RecoveryKeySection extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool showRecoveryKey;
  final VoidCallback onVerifyAndShow;
  final VoidCallback onHideRecoveryKey;

  const _RecoveryKeySection({
    required this.l10n,
    required this.theme,
    required this.showRecoveryKey,
    required this.onVerifyAndShow,
    required this.onHideRecoveryKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroupHeader(title: l10n.recoveryKeySection),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.recoveryKeyUsage,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (showRecoveryKey)
                    _RecoveryKeyDisplay(onHidden: onHideRecoveryKey)
                  else
                    FilledButton.tonal(
                      onPressed: onVerifyAndShow,
                      child: Text(l10n.viewRecoveryKey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Password management section
// =============================================================================

/// Displays the password change settings item.
class _PasswordManagementSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isChangingPassword;
  final VoidCallback onChangePassword;

  const _PasswordManagementSection({
    required this.l10n,
    required this.isChangingPassword,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroupHeader(title: l10n.changePassword),
        SettingsGroup(
          children: [
            SettingsItem(
              icon: Icons.key_outlined,
              title: l10n.changePassword,
              subtitle: l10n.reEncryptsData,
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: isChangingPassword ? null : onChangePassword,
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Danger zone section (wrapper with header)
// =============================================================================

/// Wraps the danger zone group with a section header.
class _DangerZoneSection extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onDeleteAll;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _DangerZoneSection({
    required this.isDeleting,
    required this.onDeleteAll,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsGroupHeader(title: l10n.dangerZone),
        _DangerZoneGroup(
          isDeleting: isDeleting,
          onDeleteAll: onDeleteAll,
          onExportBackup: onExportBackup,
          onImportBackup: onImportBackup,
          l10n: l10n,
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

// =============================================================================
// Encryption status hero card
// =============================================================================

/// The top status card showing encryption active/inactive with algorithm info.
class _StatusCard extends StatelessWidget {
  final bool isActive;
  final bool isUnlocked;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;

  const _StatusCard({
    required this.isActive,
    required this.isUnlocked,
    required this.colorScheme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Status colors based on encryption state
    final statusColor = isActive
        ? (isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFFFF9800) : const Color(0xFFE65100));
    final statusBg = isActive
        ? statusColor.withValues(alpha: isDark ? 0.15 : 0.08)
        : statusColor.withValues(alpha: isDark ? 0.15 : 0.08);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isActive ? Icons.verified_user : Icons.warning_amber,
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            isActive ? l10n.e2eEncryptionActiveStatus : l10n.encryptionNotSetUp,
            style: theme.textTheme.titleMedium?.copyWith(
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.encryptionAlgorithm,
            style: TextStyle(
              fontSize: 13,
              color: statusColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.keyDerivation,
            style: TextStyle(
              fontSize: 13,
              color: statusColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isUnlocked ? l10n.masterKeyUnlocked : l10n.masterKeyLocked,
            style: TextStyle(
              fontSize: 13,
              color:
                  isUnlocked ? statusColor.withValues(alpha: 0.7) : statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Cross-platform encryption warning
// =============================================================================

/// Warning card explaining that web and native encryption are incompatible.
/// Notes encrypted on one platform cannot be decrypted on the other because
/// they use different KDF algorithms (Argon2id vs PBKDF2).
class _CrossPlatformWarningCard extends StatelessWidget {
  final AppLocalizations l10n;

  const _CrossPlatformWarningCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final warningColor =
        isDark ? const Color(0xFFFFA726) : const Color(0xFFE65100);
    final bgColor = warningColor.withValues(alpha: isDark ? 0.12 : 0.06);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warningColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: warningColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.crossPlatformWarningTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.crossPlatformWarningMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Danger zone group
// =============================================================================

/// A settings group styled with danger/error colors for destructive actions.
class _DangerZoneGroup extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onDeleteAll;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  const _DangerZoneGroup({
    required this.isDeleting,
    required this.onDeleteAll,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.l10n,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = colorScheme.error;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark
        ? errorColor.withValues(alpha: 0.08)
        : errorColor.withValues(alpha: 0.04);
    final borderColor = errorColor.withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDeleting ? null : onDeleteAll,
                icon: Icon(Icons.delete_forever, color: errorColor),
                label: Text(
                  l10n.deleteAllLocalData,
                  style: TextStyle(color: errorColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: errorColor.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDeleting ? null : onExportBackup,
                icon: const Icon(Icons.download),
                label: Text(l10n.exportEncryptedBackup),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isDeleting ? null : onImportBackup,
                icon: const Icon(Icons.upload),
                label: Text(l10n.importEncryptedBackup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Recovery key display
// =============================================================================

/// Widget that loads and displays the recovery key from secure storage.
class _RecoveryKeyDisplay extends ConsumerWidget {
  final VoidCallback onHidden;

  const _RecoveryKeyDisplay({required this.onHidden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recoveryKeyAsync = ref.watch(recoveryKeyProvider);

    return recoveryKeyAsync.when(
      data: (recoveryKey) {
        if (recoveryKey == null || recoveryKey.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.noRecoveryKeyStored,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.recoveryKeyWarning,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.error.withValues(alpha: 0.8),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? const Color(0xFFF5F0EB)
                    : const Color(0xFF2C2826),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                recoveryKey,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: recoveryKey),
                    );
                    AppSnackBar.info(context, message: l10n.recoveryKeyCopied);
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(l10n.copyToClipboard),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onHidden,
                  icon: const Icon(Icons.visibility_off, size: 16),
                  label: Text(l10n.hide),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Text(
        l10n.failedToLoadRecoveryKey,
        style: TextStyle(color: theme.colorScheme.error),
      ),
    );
  }
}
