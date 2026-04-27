import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/seed_templates.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Stream of daily note dates for a given month, keyed as 'YYYY-MM'.
/// Emits a Set<String> of 'YYYY-MM-DD' strings that have daily notes.
final dailyNoteDatesProvider =
    StreamProvider.family<Set<String>, String>((ref, monthKey) {
  final db = ref.read(databaseProvider);
  // monthKey is 'YYYY-MM'. Derive start/end of month.
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final startDate = DateTime(year, month, 1);
  final endDate = DateTime(year, month + 1, 0); // last day of month
  final startStr =
      '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
  final endStr =
      '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

  return db.notePropertiesDao
      .watchDailyNoteDates(startStr, endStr)
      .map((dates) => dates.toSet());
});

/// Today's daily note ID (or null if not yet created).
final todayDailyNoteProvider = FutureProvider<String?>((ref) async {
  final db = ref.read(databaseProvider);
  final today = _dateToString(DateTime.now());
  return db.notePropertiesDao.findDailyNoteId(today);
});

/// Recent daily notes (last 7 days), returning a list of (date, noteId, title)
/// tuples.
final recentDailyNotesProvider =
    FutureProvider<List<DailyNoteEntry>>((ref) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final entries = <DailyNoteEntry>[];

  for (int i = 0; i < 7; i++) {
    final date = now.subtract(Duration(days: i));
    final dateStr = _dateToString(date);
    final noteId = await db.notePropertiesDao.findDailyNoteId(dateStr);
    if (noteId != null) {
      final note = await db.notesDao.getNoteById(noteId);
      entries.add(
        DailyNoteEntry(
          date: dateStr,
          noteId: noteId,
          title: note?.plainTitle ?? '',
          contentPreview: note?.plainContent ?? '',
        ),
      );
    }
  }

  return entries;
});

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

/// A summary entry for a daily note shown in the recent list.
class DailyNoteEntry {
  final String date;
  final String noteId;
  final String title;
  final String contentPreview;

  const DailyNoteEntry({
    required this.date,
    required this.noteId,
    required this.title,
    required this.contentPreview,
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _dateToString(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Format a date as 'MMMM d, yyyy' (e.g., 'April 25, 2026').
String _formatLongDate(DateTime date) {
  return DateFormat.yMMMMd().format(date);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DailyNotesScreen extends ConsumerStatefulWidget {
  const DailyNotesScreen({super.key});

  @override
  ConsumerState<DailyNotesScreen> createState() => _DailyNotesScreenState();
}

class _DailyNotesScreenState extends ConsumerState<DailyNotesScreen> {
  /// The month currently displayed in the calendar.
  DateTime _focusedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  /// The currently selected date in the calendar.
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final monthKey =
        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}';
    final datesAsync = ref.watch(dailyNoteDatesProvider(monthKey));

    final datesWithNotes = <String>{};
    if (datesAsync is AsyncData<Set<String>>) {
      datesWithNotes.addAll(datesAsync.value);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyNotes),
        actions: [
          // Jump to Today button
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 18),
            label: Text(l10n.goToToday),
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar widget
          _MonthCalendar(
            focusedMonth: _focusedMonth,
            selectedDate: _selectedDate,
            datesWithNotes: datesWithNotes,
            onMonthChanged: (newMonth) {
              setState(() => _focusedMonth = newMonth);
            },
            onDateSelected: (date) {
              setState(() => _selectedDate = date);
              _openOrCreateDailyNote(date);
            },
            onPreviousMonth: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                  1,
                );
              });
            },
            onNextMonth: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                  1,
                );
              });
            },
          ),

          const Divider(height: 1),

          // Selected day preview section
          _SelectedDaySection(
            selectedDate: _selectedDate,
            datesWithNotes: datesWithNotes,
            onOpen: () => _openOrCreateDailyNote(_selectedDate),
          ),

          const Divider(height: 1),

          // Recent daily notes
          Expanded(child: _RecentDailyNotesList()),
        ],
      ),
    );
  }

  /// Navigate to today's date in the calendar.
  void _goToToday() {
    setState(() {
      _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _selectedDate = DateTime.now();
    });
  }

  /// Open the daily note for [date] if it exists, otherwise create one.
  Future<void> _openOrCreateDailyNote(DateTime date) async {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    final dateStr = _dateToString(date);

    // Check if a daily note already exists for this date.
    final existingId = await db.notePropertiesDao.findDailyNoteId(dateStr);
    if (existingId != null) {
      if (mounted) {
        context.push('/notes/$existingId');
      }
      return;
    }

    // Create a new daily note using the Daily Journal template.
    final templateContent = SeedTemplates.builtIn
        .firstWhere((t) => t.name == 'Daily Journal')
        .content;
    final resolvedContent =
        templateContent.replaceAll('{{date}}', _formatLongDate(date));
    final plainTitle = _formatLongDate(date);

    final noteId = const Uuid().v4();

    String encryptedContent;
    if (crypto.isUnlocked) {
      encryptedContent = await crypto.encryptForItem(noteId, resolvedContent);
    } else {
      encryptedContent = resolvedContent;
    }

    await db.notePropertiesDao.createDailyNote(
      noteId: noteId,
      date: dateStr,
      encryptedContent: encryptedContent,
      plainContent: resolvedContent,
      plainTitle: plainTitle,
    );

    // Invalidate providers so the calendar dots update.
    ref.invalidate(dailyNoteDatesProvider);
    ref.invalidate(todayDailyNoteProvider);
    ref.invalidate(recentDailyNotesProvider);

    if (mounted) {
      context.push('/notes/$noteId');
    }
  }
}

// ---------------------------------------------------------------------------
// Month Calendar Widget
// ---------------------------------------------------------------------------

class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final Set<String> datesWithNotes;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.datesWithNotes,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final monthLabel = DateFormat.yMMMM().format(focusedMonth);
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousMonth,
                tooltip: l10n.calendar,
              ),
              Text(
                monthLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth,
                tooltip: l10n.calendar,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday headers
          _buildWeekdayHeaders(theme),

          const SizedBox(height: 4),

          // Day grid
          _buildDayGrid(context, theme, today, l10n),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders(ThemeData theme) {
    // Use locale-aware short weekday names. Start from Monday.
    final weekdays = <String>[];
    for (int i = 1; i <= 7; i++) {
      // i=1 is Monday, i=7 is Sunday
      final date = DateTime(2024, 1, i); // 2024-01-01 is a Monday
      weekdays.add(DateFormat.E().format(date));
    }

    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayGrid(
    BuildContext context,
    ThemeData theme,
    DateTime today,
    AppLocalizations l10n,
  ) {
    final firstDayOfMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    );

    // Calculate the weekday offset: Monday=0, Sunday=6.
    final int startWeekday = (firstDayOfMonth.weekday - 1) % 7;
    final int totalDays = lastDayOfMonth.day;
    final int totalCells = startWeekday + totalDays;
    final int rowCount = (totalCells / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rowCount, (rowIndex) {
        return Row(
          children: List.generate(7, (colIndex) {
            final int cellIndex = rowIndex * 7 + colIndex;
            final int dayNumber = cellIndex - startWeekday + 1;

            if (dayNumber < 1 || dayNumber > totalDays) {
              return const Expanded(child: SizedBox(height: 44));
            }

            final date = DateTime(
              focusedMonth.year,
              focusedMonth.month,
              dayNumber,
            );
            final dateStr = _dateToString(date);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final isSelected = date.year == selectedDate.year &&
                date.month == selectedDate.month &&
                date.day == selectedDate.day;
            final hasNote = datesWithNotes.contains(dateStr);

            return Expanded(
              child: Semantics(
                button: true,
                label: l10n.calendarDaySemantics(
                  _formatLongDate(date),
                  hasNote ? l10n.dailyNotes : '',
                ),
                hint: hasNote ? l10n.dailyNotes : '',
                child: GestureDetector(
                  onTap: () => onDateSelected(date),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: _DayCell(
                        dayNumber: dayNumber,
                        isToday: isToday,
                        isSelected: isSelected,
                        hasNote: hasNote,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Single Day Cell
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  final int dayNumber;
  final bool isToday;
  final bool isSelected;
  final bool hasNote;

  const _DayCell({
    required this.dayNumber,
    required this.isToday,
    required this.isSelected,
    required this.hasNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color? textColor;
    Color? bgColor;
    BoxBorder? border;

    if (isSelected) {
      bgColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isToday) {
      border = Border.all(color: colorScheme.primary, width: 2);
      textColor = colorScheme.primary;
    } else {
      textColor = colorScheme.onSurface;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: Text(
            '$dayNumber',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: isToday || isSelected ? FontWeight.bold : null,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Dot indicator for notes
        SizedBox(
          width: 6,
          height: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: hasNote
                  ? (isSelected ? colorScheme.onPrimary : colorScheme.primary)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Selected Day Section
// ---------------------------------------------------------------------------

class _SelectedDaySection extends ConsumerWidget {
  final DateTime selectedDate;
  final Set<String> datesWithNotes;
  final VoidCallback onOpen;

  const _SelectedDaySection({
    required this.selectedDate,
    required this.datesWithNotes,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateStr = _dateToString(selectedDate);
    final hasNote = datesWithNotes.contains(dateStr);
    final displayDate = _formatLongDate(selectedDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayDate,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasNote ? l10n.openDailyNote : l10n.noDailyNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hasNote
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: Icon(hasNote ? Icons.edit_note : Icons.add),
            label: Text(
              hasNote ? l10n.openDailyNote : l10n.createTodaysNote,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Daily Notes List
// ---------------------------------------------------------------------------

class _RecentDailyNotesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recentAsync = ref.watch(recentDailyNotesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.recentDailyNotes,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: recentAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return EmptyState(
                  icon: Icons.event_note_outlined,
                  title: l10n.noDailyNote,
                  subtitle: l10n.createTodaysNote,
                );
              }
              return ListView.builder(
                itemCount: entries.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _RecentDailyNoteCard(entry: entry);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent Daily Note Card
// ---------------------------------------------------------------------------

class _RecentDailyNoteCard extends StatelessWidget {
  final DailyNoteEntry entry;

  const _RecentDailyNoteCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parse the date string for display.
    final dateParts = entry.date.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    final displayDate = DateFormat.yMMMd().format(date);
    final weekday = DateFormat.EEEE().format(date);

    // Extract a preview of the content (first non-empty lines).
    final previewLines = entry.contentPreview
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(2)
        .join(' / ');
    final preview = previewLines.length > 80
        ? '${previewLines.substring(0, 80)}...'
        : previewLines;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        entry.title.isNotEmpty ? entry.title : displayDate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '$weekday${preview.isNotEmpty ? ' -- $preview' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => context.push('/notes/${entry.noteId}'),
    );
  }
}
