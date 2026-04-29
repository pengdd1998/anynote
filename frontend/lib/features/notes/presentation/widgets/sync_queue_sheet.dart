import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/offline_queue_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';

/// Bottom sheet showing sync queue details: status overview, failed operations
/// with error messages, retry and clear buttons.
class SyncQueueSheet extends ConsumerStatefulWidget {
  const SyncQueueSheet({super.key});

  @override
  ConsumerState<SyncQueueSheet> createState() => _SyncQueueSheetState();
}

class _SyncQueueSheetState extends ConsumerState<SyncQueueSheet> {
  List<SyncOperation> _failedOps = [];
  bool _isLoading = true;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _loadFailedOps();
  }

  Future<void> _loadFailedOps() async {
    final db = ref.read(databaseProvider);
    final failed = await db.syncOperationsDao.getFailedOperations();
    if (!mounted) return;
    setState(() {
      _failedOps = failed;
      _isLoading = false;
    });
  }

  Future<void> _retryAll() async {
    setState(() => _isRetrying = true);
    try {
      final service = ref.read(offlineQueueServiceProvider.notifier);
      await service.retryFailed();
      await _loadFailedOps();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  Future<void> _clearCompleted() async {
    final service = ref.read(offlineQueueServiceProvider.notifier);
    await service.clearCompleted();
    await _loadFailedOps();

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    AppSnackBar.info(context, message: l10n.queueCleared);
  }

  @override
  Widget build(BuildContext context) {
    final queueStatusAsync = ref.watch(offlineQueueServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final queueStatus =
        queueStatusAsync.valueOrNull ?? const OfflineQueueStatus();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.sync, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.syncQueue,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Status overview cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatusCard(
                    theme: theme,
                    label: l10n.pendingOperations,
                    count: queueStatus.pendingCount,
                    icon: Icons.schedule,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildStatusCard(
                    theme: theme,
                    label: l10n.failedOperations,
                    count: queueStatus.failedCount,
                    icon: Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
            ),

            // Failed operations list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _failedOps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.noPendingOperations,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _failedOps.length,
                          itemBuilder: (context, index) {
                            final op = _failedOps[index];
                            return _buildFailedOpTile(
                              op: op,
                              theme: theme,
                              l10n: l10n,
                            );
                          },
                        ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _failedOps.isEmpty || _isRetrying ? null : _retryAll,
                      icon: _isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.retryAll),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearCompleted,
                      icon: const Icon(
                        Icons.cleaning_services_outlined,
                        size: 18,
                      ),
                      label: Text(l10n.clearCompleted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard({
    required ThemeData theme,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedOpTile({
    required SyncOperation op,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        Icons.error_outline,
        size: 18,
        color: theme.colorScheme.error,
      ),
      title: Text(
        '${_operationTypeLabel(op.operationType)} ${op.itemType} ${op.itemId.substring(0, 8)}...',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: op.lastError != null
          ? Text(
              l10n.operationFailed(
                op.lastError!.length > 80
                    ? '${op.lastError!.substring(0, 80)}...'
                    : op.lastError!,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Text(
        '${op.retryCount}/5',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _operationTypeLabel(String type) {
    switch (type) {
      case 'create':
        return 'Create';
      case 'update':
        return 'Update';
      case 'delete':
        return 'Delete';
      default:
        return type;
    }
  }
}
