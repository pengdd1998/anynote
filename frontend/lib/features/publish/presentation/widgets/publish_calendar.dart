import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/publish_providers.dart';

// ignore: unused_import

/// Content calendar for published posts: a hand-rolled month grid (no
/// TableCalendar dependency) with a dot under each day that has publishes.
/// Tapping a day lists that day's posts in a bottom sheet (Phase 131).
class PublishCalendarView extends ConsumerStatefulWidget {
  const PublishCalendarView({super.key});

  @override
  ConsumerState<PublishCalendarView> createState() =>
      _PublishCalendarViewState();
}

class _PublishCalendarViewState extends ConsumerState<PublishCalendarView> {
  DateTime _focusedMonth = DateTime.now();

  DateTime _dayOf(String iso) => DateTime.parse(iso).toLocal();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyAsync = ref.watch(publishHistoryProvider);

    return historyAsync.when(
      data: (history) {
        // Day -> entries, keyed by local calendar date.
        final byDay = <DateTime, List<Map<String, dynamic>>>{};
        for (final item in history) {
          final created = item['created_at']?.toString();
          if (created == null || created.isEmpty) continue;
          final day = _dayOf(created);
          final key = DateTime(day.year, day.month, day.day);
          byDay.putIfAbsent(key, () => []).add(item);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            children: [
              _buildMonthHeader(l10n, isDark),
              const SizedBox(height: AppSpacing.s4),
              _buildWeekdayHeaders(isDark),
              const SizedBox(height: AppSpacing.s4),
              _buildDayGrid(l10n, isDark, byDay),
              const SizedBox(height: AppSpacing.lg),
              // Month summary strip: count and platforms for context.
              _buildMonthSummary(l10n, isDark, history, byDay),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          l10n.failedToLoadPublishHistory,
          style: AppTextStyles.caption.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(AppLocalizations l10n, bool isDark) {
    final monthLabel = DateFormat.yMMMM().format(_focusedMonth);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(() {
            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
          }),
        ),
        Expanded(
          child: Center(
            child: Text(
              monthLabel,
              style: AppTextStyles.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(() {
            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
          }),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeaders(bool isDark) {
    final weekdays = <String>[];
    for (int i = 1; i <= 7; i++) {
      // 2024-01-01 is a Monday; i=1..7 walks Mon..Sun.
      weekdays.add(DateFormat.E().format(DateTime(2024, 1, i)));
    }
    return Row(
      children: weekdays
          .map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayGrid(
    AppLocalizations l10n,
    bool isDark,
    Map<DateTime, List<Map<String, dynamic>>> byDay,
  ) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    // Monday=0 .. Sunday=6, matching the header order.
    final startWeekday = (firstDay.weekday - 1) % 7;
    final rowCount = ((startWeekday + lastDay.day) / 7).ceil();
    final today = DateTime.now();
    final muted = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: List.generate(rowCount, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNumber = cellIndex - startWeekday + 1;
              if (dayNumber < 1 || dayNumber > lastDay.day) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                dayNumber,
              );
              final entries = byDay[date] ?? const [];
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final hasPublished = entries.any(
                (e) => e['status']?.toString() == 'published',
              );

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  onTap:
                      entries.isEmpty ? null : () => _showDaySheet(l10n, date, entries),
                  child: SizedBox(
                    height: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: isToday
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withAlpha(25),
                                )
                              : null,
                          child: Text(
                            '$dayNumber',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 13,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w400,
                              color: entries.isEmpty
                                  ? muted
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Dot: solid for months with published posts,
                        // hollow for drafts/pending only.
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: entries.isEmpty
                                ? Colors.transparent
                                : hasPublished
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildMonthSummary(
    AppLocalizations l10n,
    bool isDark,
    List<Map<String, dynamic>> history,
    Map<DateTime, List<Map<String, dynamic>>> byDay,
  ) {
    var monthCount = 0;
    byDay.forEach((day, entries) {
      if (day.year == _focusedMonth.year &&
          day.month == _focusedMonth.month) {
        monthCount += entries.length;
      }
    });
    final muted = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;
    return Text(
      l10n.publicationsInMonth(monthCount),
      style: AppTextStyles.caption.copyWith(color: muted),
    );
  }

  void _showDaySheet(
    AppLocalizations l10n,
    DateTime day,
    List<Map<String, dynamic>> entries,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat.yMMMd().format(day),
                  style: AppTextStyles.headline.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (ctx, index) =>
                    _DayEntryTile(item: entries[index], isDark: isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayEntryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;

  const _DayEntryTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = item['title']?.toString() ?? l10n.untitled;
    final platform = item['platform']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    String time = '';
    if (createdAt.isNotEmpty) {
      try {
        time = DateFormat.Hm().format(DateTime.parse(createdAt).toLocal());
      } catch (_) {}
    }

    final statusColor = switch (status) {
      'published' => AppColors.success,
      'failed' => AppColors.error,
      _ => AppColors.warning,
    };
    final statusIcon = switch (status) {
      'published' => Icons.check_circle,
      'failed' => Icons.error,
      'publishing' => Icons.sync,
      _ => Icons.schedule,
    };

    return ListTile(
      leading: Icon(statusIcon, color: statusColor, size: 20),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
      subtitle: Text(
        [platform, if (time.isNotEmpty) time].join(' · '),
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          color: isDark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
      ),
    );
  }
}
