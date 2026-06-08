import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/crypto/master_key.dart';
import '../../../../core/error/error.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/collab/ws_client.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../data/settings_providers.dart';

/// Sign-out section for the settings screen.
///
/// Contains the destructive sign-out button and account deletion option.
class SignOutSection extends ConsumerWidget {
  const SignOutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsGroup(
      children: [
        DestructiveSettingsItem(
          icon: AppIcons.logout,
          title: l10n.signOut,
          onTap: () => _confirmSignOut(context, ref),
        ),
        DestructiveSettingsItem(
          icon: Icons.delete_forever,
          title: l10n.deleteAccount,
          onTap: () => _confirmDeleteAccount(context, ref),
        ),
      ],
    );
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

      // Disconnect WebSocket for real-time collaboration.
      ref.read(wsClientProvider.notifier).disconnect();

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
        AppSnackBar.error(
          context,
          message: l10n.signOutFailed(
            ErrorDisplay.displayMessage(e, l10n),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();

    // Step 1: Password confirmation dialog.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountWarning),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.password,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              scrollPadding: const EdgeInsets.only(bottom: 120),
            ),
          ],
        ),
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
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );

    passwordController.dispose();
    if (confirmed != true || !context.mounted) return;

    // Step 2: Final confirmation.
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountFinalWarning),
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
            child: Text(l10n.deleteAccountPermanently),
          ),
        ],
      ),
    );

    if (finalConfirm != true || !context.mounted) return;

    try {
      // Derive auth key hash from master key for server verification.
      final masterKey = await MasterKeyManager.getStoredMasterKey();
      if (masterKey == null) throw Exception('Master key not available');

      final authKey = await MasterKeyManager.deriveAuthKey(masterKey);
      final authKeyHashHex = await MasterKeyManager.hashAuthKey(authKey);
      // Convert hex hash to base64 (same as login/register flow).
      final authKeyHashBytes = _hexToBytes(authKeyHashHex);
      final authKeyHashBase64 = base64Encode(authKeyHashBytes);

      // Call the server to delete the account.
      final api = ref.read(apiClientProvider);
      await api.deleteAccount(authKeyHashBase64);

      // Disconnect WebSocket.
      ref.read(wsClientProvider.notifier).disconnect();

      // Unregister push notifications.
      await ref.read(pushNotificationServiceProvider).dispose();

      // Clear all local data.
      await MasterKeyManager.clearAll();
      final db = ref.read(databaseProvider);
      await db.close();
      await api.logout();

      ref.read(authStateProvider.notifier).state = false;

      if (context.mounted) {
        context.go('/auth/login');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          message: l10n.deleteAccountFailed(
            ErrorDisplay.displayMessage(e, l10n),
          ),
        );
      }
    }
  }

  Uint8List _hexToBytes(String hex) {
    hex = hex.toLowerCase().replaceAll(RegExp(r'[^0-9a-f]'), '');
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] =
          (int.parse(hex[i * 2], radix: 16) << 4) +
          int.parse(hex[i * 2 + 1], radix: 16);
    }
    return result;
  }
}

/// Separate widget for the sync button so it can use ConsumerStatefulWidget
/// to show a loading spinner during sync.
class SyncButton extends ConsumerStatefulWidget {
  const SyncButton({super.key});

  @override
  ConsumerState<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<SyncButton> {
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
        AppSnackBar.info(context, message: msg);
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
