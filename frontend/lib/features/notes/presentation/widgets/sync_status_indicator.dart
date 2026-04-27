import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sync/offline_queue_service.dart';
import '../../../../l10n/app_localizations.dart';
import 'sync_queue_sheet.dart';

/// Compact sync status indicator for the app bar.
///
/// Shows a colored dot indicating sync state:
/// - Green: all synced
/// - Yellow: pending operations
/// - Red: failed operations
class SyncStatusIndicator extends ConsumerWidget {
  final VoidCallback? onTap;

  const SyncStatusIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueStatusAsync = ref.watch(offlineQueueServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return queueStatusAsync.when(
      data: (status) => _buildIndicator(context, status, l10n, theme),
      loading: () => _buildDot(context, Colors.grey, 'Synced', theme),
      error: (_, __) => _buildDot(context, Colors.grey, 'Synced', theme),
    );
  }

  Widget _buildIndicator(
    BuildContext context,
    OfflineQueueStatus status,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (status.hasFailed) {
      return _buildDot(
        context,
        theme.colorScheme.error,
        l10n.syncFailedCount(status.failedCount),
        theme,
      );
    }
    if (status.hasPending) {
      return _buildDot(
        context,
        Colors.orange,
        l10n.pendingSync(status.pendingCount),
        theme,
      );
    }
    return _buildDot(context, Colors.green, 'Synced', theme);
  }

  Widget _buildDot(
    BuildContext context,
    Color color,
    String tooltip,
    ThemeData theme,
  ) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap ??
            () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const SyncQueueSheet(),
              );
            },
        child: Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
