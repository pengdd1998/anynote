import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_providers.dart';
import '../error/connectivity_provider.dart';
import '../sync/sync_lifecycle.dart';

/// Compact sync status widget for use in the app bar.
///
/// Shows a sync icon that rotates while syncing, a red badge with the
/// pending operations count when there are queued items, and tints the
/// icon differently when the device is offline.
///
/// Tapping the widget shows a bottom sheet with sync details: pending
/// count, last sync time, and failed operations.
class SyncStatusWidget extends ConsumerStatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  ConsumerState<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends ConsumerState<SyncStatusWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncIconController;

  @override
  void initState() {
    super.initState();
    _syncIconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _syncIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueManager = ref.watch(syncQueueManagerProvider);
    final connectivity = ref.watch(connectivityProvider);
    final lifecycle = ref.watch(syncLifecycleProvider);
    final isOffline = connectivity.valueOrNull == false;
    final isSyncing = lifecycle.isActive && !isOffline;

    // Animate the sync icon rotation when syncing.
    if (isSyncing) {
      _syncIconController.repeat();
    } else {
      _syncIconController.stop();
    }

    return StreamBuilder<int>(
      stream: queueManager.watchPendingCount(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        return IconButton(
          onPressed: () => _showSyncDetails(
            context,
            pendingCount,
            isOffline,
            lifecycle.lastSyncAt,
            queueManager,
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              // Sync icon with optional rotation animation.
              RotationTransition(
                turns: _syncIconController,
                child: Icon(
                  _iconForState(isOffline, isSyncing, pendingCount),
                  size: 22,
                  color: _colorForState(isOffline, isSyncing, context),
                ),
              ),
              // Red badge showing pending count.
              if (pendingCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: _tooltipForState(isOffline, isSyncing, pendingCount),
        );
      },
    );
  }

  IconData _iconForState(bool isOffline, bool isSyncing, int pendingCount) {
    if (isOffline) return Icons.cloud_off;
    if (isSyncing) return Icons.sync;
    if (pendingCount > 0) return Icons.cloud_upload;
    return Icons.cloud_done;
  }

  Color _colorForState(bool isOffline, bool isSyncing, BuildContext context) {
    if (isOffline) return Theme.of(context).colorScheme.error;
    if (isSyncing) return Theme.of(context).colorScheme.primary;
    return Colors.green;
  }

  String _tooltipForState(bool isOffline, bool isSyncing, int pendingCount) {
    if (isOffline) return 'Offline -- changes will sync when connected';
    if (isSyncing) return 'Syncing...';
    if (pendingCount > 0) return '$pendingCount pending operation${pendingCount == 1 ? '' : 's'}';
    return 'All changes synced';
  }

  void _showSyncDetails(
    BuildContext context,
    int pendingCount,
    bool isOffline,
    DateTime? lastSyncAt,
    dynamic queueManager,
  ) {
    final theme = Theme.of(context);
    final lastSyncText = lastSyncAt != null
        ? '${lastSyncAt.hour.toString().padLeft(2, '0')}:${lastSyncAt.minute.toString().padLeft(2, '0')}'
        : 'Never';

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sync Status',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                icon: isOffline ? Icons.wifi_off : Icons.wifi,
                label: isOffline ? 'Offline' : 'Connected',
                valueColor: isOffline ? theme.colorScheme.error : Colors.green,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                icon: Icons.cloud_upload_outlined,
                label: 'Pending operations',
                value: '$pendingCount',
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                icon: Icons.access_time,
                label: 'Last synced',
                value: lastSyncText,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(syncLifecycleProvider).syncNow();
                  },
                  child: const Text('Sync now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (value != null)
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
      ],
    );
  }
}
