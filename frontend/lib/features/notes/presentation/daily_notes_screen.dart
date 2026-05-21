import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/database/seed_templates.dart';
import '../../../core/error/error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
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

          const SizedBox(height: AppSpacing.s8),

          // Selected day preview section
          _SelectedDaySection(
            selectedDate: _selectedDate,
            datesWithNotes: datesWithNotes,
            onOpen: () => _openOrCreateDailyNote(_selectedDate),
          ),

          const SizedBox(height: AppSpacing.s12),

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
      encryptedContent =
          await crypto.encryptForItem(noteId, resolvedContent);
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
    final l10n = AppLocalizations.of(context)!;
    final monthLabel = DateFormat.yMMMM().format(focusedMonth);
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month navigation header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousMonth,
                tooltip: l10n.calendar,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel,
                    style: AppTextStyles.headline.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth,
                tooltip: l10n.calendar,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // Weekday headers
          _buildWeekdayHeaders(),

          const SizedBox(height: AppSpacing.s4),

          // Day grid
          _buildDayGrid(context, today, l10n),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeaders() {
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
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.lightTextTertiary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayGrid(
    BuildContext context,
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
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: Row(
            children: List.generate(7, (colIndex) {
              final int cellIndex = rowIndex * 7 + colIndex;
              final int dayNumber = cellIndex - startWeekday + 1;

              if (dayNumber < 1 || dayNumber > totalDays) {
                return const Expanded(
                  child: SizedBox(height: 48),
                );
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
                      height: 48,
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
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final Color bg;
    final Color textColor;

    if (isSelected) {
      bg = primary.withAlpha(30);
      textColor = primary;
    } else if (isToday) {
      bg = isDark
          ? AppColors.darkInputFill
          : AppColors.lightInputFill;
      textColor = primary;
    } else {
      bg = Colors.transparent;
      textColor = isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            '$dayNumber',
            style: AppTextStyles.caption.copyWith(
              fontSize: 14,
              color: textColor,
              fontWeight: isSelected || isToday
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Dot indicator for notes
        SizedBox(
          width: 5,
          height: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: hasNote
                  ? primary.withAlpha(isSelected ? 200 : 120)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = _dateToString(selectedDate);
    final hasNote = datesWithNotes.contains(dateStr);
    final displayDate = _formatLongDate(selectedDate);
    final weekday = DateFormat.EEEE().format(selectedDate);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.smOf(Theme.of(context).brightness),
          ),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasNote
                      ? primary.withAlpha(15)
                      : (isDark
                          ? AppColors.darkInputFill
                          : AppColors.lightInputFill),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${selectedDate.day}',
                      style: AppTextStyles.headline.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: hasNote ? primary : null,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      weekday.substring(0, 3),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Date info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayDate,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasNote ? l10n.openDailyNote : l10n.noDailyNote,
                      style: AppTextStyles.caption.copyWith(
                        color: hasNote
                            ? primary
                            : (isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary),
                      ),
                    ),
                  ],
                ),
              ),
              // Action icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  hasNote ? Icons.edit_note : Icons.add,
                  size: 20,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
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
    final recentAsync = ref.watch(recentDailyNotesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.s4,
            AppSpacing.md,
            AppSpacing.s8,
          ),
          child: Text(
            l10n.recentDailyNotes,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
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
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: _RecentDailyNoteCard(entry: entry),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                ErrorDisplay.displayMessage(e, AppLocalizations.of(context)!),
              ),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse the date string for display.
    final dateParts = entry.date.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
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

    final cardBg = isDark ? AppColors.darkCardBg : AppColors.lightCardBg;

    return GestureDetector(
      onTap: () => context.push('/notes/${entry.noteId}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.smOf(Theme.of(context).brightness),
        ),
        child: Row(
          children: [
            // Day number badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkInputFill
                    : AppColors.lightInputFill,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: AppTextStyles.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            // Title + preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isNotEmpty ? entry.title : weekday,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$weekday${preview.isNotEmpty ? ' · $preview' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
