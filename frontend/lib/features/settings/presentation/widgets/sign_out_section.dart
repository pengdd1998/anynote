import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../data/settings_providers.dart';

/// Sign-out section for the settings screen.
///
/// Contains the destructive sign-out button and its confirmation logic.
class SignOutSection extends ConsumerWidget {
  const SignOutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsGroup(
      children: [
        DestructiveSettingsItem(
          icon: Icons.logout,
          title: l10n.signOut,
          onTap: () => _confirmSignOut(context, ref),
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
