import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/daos/note_properties_dao.dart';
import '../../../../core/notifications/reminder_service.dart';
import '../../../../l10n/app_localizations.dart';

/// Bottom sheet for picking or managing a reminder on a note.
///
/// Shows preset quick-pick options, a date/time picker, recurring selector,
/// and the ability to remove an existing reminder.
class ReminderPickerSheet extends ConsumerStatefulWidget {
  final String noteId;
  final String? noteTitle;

  const ReminderPickerSheet({
    super.key,
    required this.noteId,
    this.noteTitle,
  });

  @override
  ConsumerState<ReminderPickerSheet> createState() =>
      _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends ConsumerState<ReminderPickerSheet> {
  ReminderEntry? _currentReminder;
  bool _isLoading = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _recurring = 'none';

  @override
  void initState() {
    super.initState();
    _loadCurrentReminder();
  }

  Future<void> _loadCurrentReminder() async {
    final service = ref.read(reminderServiceProvider);
    final reminder = await service.getReminderForNote(widget.noteId);
    if (!mounted) return;
    setState(() {
      _currentReminder = reminder;
      if (reminder != null) {
        _selectedDate = reminder.reminderAt;
        _selectedTime = TimeOfDay.fromDateTime(reminder.reminderAt);
        _recurring = reminder.recurring;
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            l10n.setReminder,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Current reminder display
            if (_currentReminder != null) ...[
              _buildCurrentReminderChip(context, l10n, theme),
              const SizedBox(height: 16),
            ],

            // Quick pick presets
            Text(
              l10n.quickCapture,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip(
                  context: context,
                  label: l10n.laterToday,
                  icon: Icons.access_time,
                  onTap: () => _applyPreset(_laterToday()),
                ),
                _buildPresetChip(
                  context: context,
                  label: l10n.tomorrowMorning,
                  icon: Icons.wb_sunny_outlined,
                  onTap: () => _applyPreset(_tomorrowMorning()),
                ),
                _buildPresetChip(
                  context: context,
                  label: l10n.nextWeek,
                  icon: Icons.event_outlined,
                  onTap: () => _applyPreset(_nextWeek()),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Custom date/time picker row
            Text(
              l10n.reminderAt,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerTile(context, l10n),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimePickerTile(context, l10n),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recurring selector
            Text(
              l10n.recurring,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRecurringChip(l10n.none, 'none'),
                _buildRecurringChip(l10n.daily, 'daily'),
                _buildRecurringChip(l10n.weekly, 'weekly'),
                _buildRecurringChip(l10n.monthly, 'monthly'),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentReminder != null)
                  TextButton(
                    onPressed: _removeReminder,
                    child: Text(
                      l10n.removeReminder,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedDate != null ? _setReminder : null,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentReminderChip(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final reminder = _currentReminder!;
    final timeStr = _formatDateTime(reminder.reminderAt);
    final recurStr = reminder.isRecurring
        ? ' (${_recurringLabel(l10n, reminder.recurring)})'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$timeStr$recurStr',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
  }

  Widget _buildDatePickerTile(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final dateStr = _selectedDate != null
        ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
        : l10n.selectAnItemToView;

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                dateStr,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final timeStr = _selectedTime != null
        ? _selectedTime!.format(context)
        : l10n.selectAnItemToView;

    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                timeStr,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _recurring == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _recurring = value);
      },
      selectedColor: theme.colorScheme.secondaryContainer,
    );
  }

  // -- Preset helpers --

  DateTime _laterToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 2, now.minute);
  }

  DateTime _tomorrowMorning() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9, 0);
  }

  DateTime _nextWeek() {
    final now = DateTime.now();
    // Find the next Monday.
    int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    return DateTime(now.year, now.month, now.day + daysUntilMonday, 9, 0);
  }

  void _applyPreset(DateTime dt) {
    setState(() {
      _selectedDate = dt;
      _selectedTime = TimeOfDay.fromDateTime(dt);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _setReminder() async {
    if (_selectedDate == null) return;

    final date = _selectedDate!;
    final time = _selectedTime ?? TimeOfDay.now();
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final service = ref.read(reminderServiceProvider);
    await service.scheduleReminder(
      widget.noteId,
      dateTime,
      title: widget.noteTitle,
      recurring: _recurring == 'none' ? null : _recurring,
    );

    // Invalidate the upcoming reminders provider so the list refreshes.
    ref.invalidate(upcomingRemindersProvider);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _removeReminder() async {
    final service = ref.read(reminderServiceProvider);
    await service.cancelReminder(widget.noteId);
    ref.invalidate(upcomingRemindersProvider);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      return dt.toLocal().toString().substring(0, 16);
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ${diff.inHours % 24}h';
    }
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
        return l10n.none;
    }
  }
}
