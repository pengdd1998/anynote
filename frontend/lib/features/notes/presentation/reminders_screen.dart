import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/daos/note_properties_dao.dart';
import '../../../core/notifications/reminder_service.dart';
import '../../../l10n/app_localizations.dart';

/// Screen that displays all upcoming reminders sorted by time.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reminders),
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(e.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (reminders) {
          if (reminders.isEmpty) {
            return _buildEmptyState(context, l10n);
          }
          return _buildReminderList(context, ref, reminders, l10n);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noReminders,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setReminder,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderList(
    BuildContext context,
    WidgetRef ref,
    List<ReminderEntry> reminders,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () => ref.read(upcomingRemindersProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          final isOverdue = reminder.reminderAt.isBefore(now);
          final isRecurring = reminder.isRecurring;

          return Dismissible(
            key: ValueKey(reminder.noteId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: theme.colorScheme.error,
              child:
                  Icon(Icons.delete_outline, color: theme.colorScheme.onError),
            ),
            confirmDismiss: (_) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.removeReminder),
                  content: Text(l10n.deleteNoteDialogMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        l10n.removeReminder,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) async {
              final service = ref.read(reminderServiceProvider);
              await service.cancelReminder(reminder.noteId);
              ref.invalidate(upcomingRemindersProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.removeReminder),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(
                  isOverdue
                      ? Icons.notifications_active
                      : Icons.notifications_outlined,
                  color: isOverdue
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  reminder.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _formatRelativeTime(reminder.reminderAt, now, l10n),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isOverdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isRecurring) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.repeat,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _recurringLabel(l10n, reminder.recurring),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  // Navigate to the note.
                  context.push('/notes/${reminder.noteId}');
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatRelativeTime(
    DateTime target,
    DateTime now,
    AppLocalizations l10n,
  ) {
    final diff = target.difference(now);

    if (diff.isNegative) {
      // Overdue
      final absDiff = diff.abs();
      if (absDiff.inMinutes < 1) {
        return l10n.justNow;
      }
      if (absDiff.inHours < 1) {
        return l10n.minutesAgo(absDiff.inMinutes);
      }
      if (absDiff.inDays < 1) {
        return l10n.hoursAgo(absDiff.inHours);
      }
      return l10n.daysAgo(absDiff.inDays);
    }

    // Future
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    }
    return '${target.month}/${target.day} ${target.hour}:${target.minute.toString().padLeft(2, '0')}';
  }

  String _recurringLabel(AppLocalizations l10n, String recurring) {
    switch (recurring) {
      case 'daily':
        return l10n.daily;
      case 'weekly':
        return l10n.weekly;
      case 'monthly':
        return l10n.monthly;
      default:
        return '';
    }
  }
}
