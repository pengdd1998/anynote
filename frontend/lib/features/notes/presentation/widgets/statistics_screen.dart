import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../search/data/statistics_providers.dart';
import '../../domain/note_statistics.dart';

/// Screen displaying note statistics and writing insights.
///
/// Shows overview cards, writing streaks, monthly activity chart,
/// top tags, collections, status/priority distributions, and knowledge
/// graph stats. All data is computed from SQL aggregation via the
/// [noteStatisticsProvider].
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(noteStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.statistics ?? 'Statistics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: statsAsync.when(
        data: (stats) {
          if (stats.totalNotes == 0) {
            return _EmptyState(l10n: l10n);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewCards(stats: stats),
                const SizedBox(height: AppSpacing.lg),
                _WritingStreakCard(streak: stats.writingStreak),
                const SizedBox(height: AppSpacing.lg),
                _MonthlyActivityChart(notesByMonth: stats.notesByMonth),
                const SizedBox(height: AppSpacing.lg),
                _TopTagsSection(topTags: stats.topTags),
                const SizedBox(height: AppSpacing.lg),
                _TopCollectionsSection(
                  topCollections: stats.topCollections,
                  totalNotes: stats.totalNotes,
                ),
                const SizedBox(height: AppSpacing.lg),
                _StatusDistributionSection(
                  distribution: stats.statusDistribution,
                ),
                const SizedBox(height: AppSpacing.lg),
                _PriorityDistributionSection(
                  distribution: stats.priorityDistribution,
                ),
                const SizedBox(height: AppSpacing.lg),
                _KnowledgeGraphSection(stats: stats),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorStateWidget(
          message:
              '${l10n?.failedToLoadNote ?? 'Error loading statistics'}\n${err.toString()}',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Warm card wrapper
// ---------------------------------------------------------------------------

class _WarmCard extends StatelessWidget {
  final Widget child;

  const _WarmCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.smOf(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final AppLocalizations? l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkInputFill
                  : AppColors.lightInputFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.bar_chart_outlined,
              size: 28,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n?.noStatistics ?? 'No statistics yet',
            style: AppTextStyles.title.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              l10n?.createFirstNoteHint ??
                  'Create your first note to see statistics',
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview cards (2x2 grid)
// ---------------------------------------------------------------------------

class _OverviewCards extends StatelessWidget {
  final NoteStatistics stats;

  const _OverviewCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.s12,
      crossAxisSpacing: AppSpacing.s12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        StatCard(
          icon: Icons.description_outlined,
          label: AppLocalizations.of(context)?.totalNotes ?? 'Total Notes',
          value: _formatNumber(stats.totalNotes),
          color: AppColors.accentLavender,
        ),
        StatCard(
          icon: Icons.text_fields_outlined,
          label: AppLocalizations.of(context)?.totalWords ?? 'Total Words',
          value: _formatNumber(stats.totalWords),
          color: AppColors.accentMintText,
        ),
        StatCard(
          icon: Icons.analytics_outlined,
          label:
              AppLocalizations.of(context)?.averageWords ?? 'Avg Words/Note',
          value: stats.averageWordsPerNote.toStringAsFixed(0),
          color: AppColors.accentYellowText,
        ),
        StatCard(
          icon: Icons.calendar_month_outlined,
          label: AppLocalizations.of(context)?.daysActive ?? 'Days Active',
          value: _formatNumber(
            stats.writingStreak.activeDaysLast30.length,
          ),
          color: AppColors.accentPeachText,
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ---------------------------------------------------------------------------
// Writing streak card
// ---------------------------------------------------------------------------

class _WritingStreakCard extends StatelessWidget {
  final WritingStreak streak;

  const _WritingStreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasStreak = streak.currentStreak > 0;

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasStreak
                      ? AppColors.accentYellow.withAlpha(40)
                      : (isDark
                          ? AppColors.darkInputFill
                          : AppColors.lightInputFill),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  Icons.local_fire_department_outlined,
                  size: 18,
                  color: hasStreak
                      ? AppColors.warning
                      : (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n?.writingStreak ?? 'Writing Streak',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Streak numbers
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.currentStreak(streak.currentStreak) ??
                          'Current: ${streak.currentStreak} days',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n?.longestStreak(streak.longestStreak) ??
                          'Longest: ${streak.longestStreak} days',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Hero streak number
              if (hasStreak)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentYellowBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${streak.currentStreak}',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentYellowText,
                      height: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Streak calendar
          _StreakCalendar(activeDays: streak.activeDaysLast30),
        ],
      ),
    );
  }
}

/// Compact 30-day calendar showing active days as soft rounded squares.
class _StreakCalendar extends StatelessWidget {
  final Set<String> activeDays;

  const _StreakCalendar({required this.activeDays});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 29));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)?.last30Days ?? 'Last 30 days',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(30, (i) {
            final date = startDate.add(Duration(days: i));
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final isActive = activeDays.contains(key);
            return Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withAlpha(140)
                    : (isDark
                        ? AppColors.darkInputFill
                        : AppColors.lightInputFill),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly activity bar chart
// ---------------------------------------------------------------------------

class _MonthlyActivityChart extends StatelessWidget {
  final Map<String, int> notesByMonth;

  const _MonthlyActivityChart({required this.notesByMonth});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final months = <String>[];
    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(
        '${date.year}-${date.month.toString().padLeft(2, '0')}',
      );
    }

    final maxCount = notesByMonth.values.fold<int>(0, max);
    final barMaxHeight = maxCount > 0 ? maxCount.toDouble() : 1.0;

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.monthlyActivity ?? 'Monthly Activity',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 150,
            child: Semantics(
              label: l10n?.barChartSemanticLabel(
                    months.map((m) {
                      final count = notesByMonth[m] ?? 0;
                      return '${m.substring(5)}: $count';
                    }).join(', '),
                  ) ??
                  'Bar chart showing notes by month: ${months.map((m) => '${m.substring(5)}: ${notesByMonth[m] ?? 0}').join(', ')}',
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarChartPainter(
                  months: months,
                  values: notesByMonth,
                  maxValue: barMaxHeight,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for a soft bar chart with rounded tops.
class _BarChartPainter extends CustomPainter {
  final List<String> months;
  final Map<String, int> values;
  final double maxValue;
  final bool isDark;

  _BarChartPainter({
    required this.months,
    required this.values,
    required this.maxValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty || size.width <= 0 || size.height <= 0) return;

    final barAreaHeight = size.height - 20;
    final barWidth = (size.width - (months.length - 1) * 4) / months.length;
    final clampedBarWidth = barWidth.clamp(8.0, 40.0);

    // Subtle grid lines.
    final gridColor = isDark
        ? AppColors.darkDivider.withAlpha(40)
        : AppColors.lightDivider.withAlpha(50);
    final gridPaint = Paint()..color = gridColor;
    for (int i = 0; i <= 4; i++) {
      final y = barAreaHeight * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final labelColor = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;

    for (int i = 0; i < months.length; i++) {
      final count = values[months[i]] ?? 0;
      final barHeight =
          maxValue > 0 ? (count / maxValue) * barAreaHeight : 0.0;

      final x = i * (clampedBarWidth + 4);
      final y = barAreaHeight - barHeight;

      if (barHeight > 0) {
        // Soft gradient-like bar: lighter at top, slightly darker at bottom.
        final barRadius = Radius.circular(clampedBarWidth / 3);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, clampedBarWidth, barHeight),
          topLeft: barRadius,
          topRight: barRadius,
        );

        final barPaint = Paint()
          ..color = AppColors.primary.withAlpha(160);
        canvas.drawRRect(rect, barPaint);
      }

      // Month label.
      final label = months[i].substring(5);
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(color: labelColor, fontSize: 9),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          x + (clampedBarWidth - textPainter.width) / 2,
          barAreaHeight + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.months != months || oldDelegate.values != values;
  }
}

// ---------------------------------------------------------------------------
// Top tags section
// ---------------------------------------------------------------------------

class _TopTagsSection extends StatelessWidget {
  final List<TagStat> topTags;

  const _TopTagsSection({required this.topTags});

  @override
  Widget build(BuildContext context) {
    if (topTags.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.topTags ?? 'Top Tags',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: topTags.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
              itemBuilder: (context, index) {
                final tag = topTags[index];
                final accentBg =
                    AppColors.accentBackgrounds[index % AppColors.accentBackgrounds.length];
                final accentTextColors = [
                  AppColors.accentPeachText,
                  AppColors.accentYellowText,
                  AppColors.accentMintText,
                  AppColors.accentPeachText,
                ];
                final accentText =
                    accentTextColors[index % accentTextColors.length];
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: accentBg,
                    child: Text(
                      '${tag.noteCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  label: Text(tag.tagName),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top collections section
// ---------------------------------------------------------------------------

class _TopCollectionsSection extends StatelessWidget {
  final List<CollectionStat> topCollections;
  final int totalNotes;

  const _TopCollectionsSection({
    required this.topCollections,
    required this.totalNotes,
  });

  @override
  Widget build(BuildContext context) {
    if (topCollections.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final maxCount = topCollections.first.noteCount;

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.topCollections ?? 'Top Collections',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          ...topCollections.map((col) {
            final percent = totalNotes > 0
                ? (col.noteCount / totalNotes * 100).toStringAsFixed(0)
                : '0';
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          col.collectionTitle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppTextStyles.body,
                        ),
                      ),
                      Text(
                        '${col.noteCount} ($percent%)',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: maxCount > 0 ? col.noteCount / maxCount : 0,
                      backgroundColor: isDark
                          ? AppColors.darkInputFill
                          : AppColors.lightInputFill,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status distribution section
// ---------------------------------------------------------------------------

class _StatusDistributionSection extends StatelessWidget {
  final Map<String, int> distribution;

  const _StatusDistributionSection({required this.distribution});

  static const _statusColors = <String, Color>{
    'Todo': AppColors.primary,
    'In Progress': AppColors.accentPeachText,
    'Done': AppColors.accentMintText,
    'Blocked': AppColors.error,
    'Cancelled': AppColors.lightTextTertiary,
  };

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final total = distribution.values.fold<int>(0, (sum, c) => sum + c);

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.statusDistribution ?? 'Status Distribution',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Stacked horizontal bar with rounded ends.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 20,
              child: Row(
                children: distribution.entries.map((entry) {
                  final fraction = total > 0 ? entry.value / total : 0.0;
                  final color = _statusColors[entry.key] ??
                      AppColors.lightTextTertiary.withAlpha(100);
                  return Expanded(
                    flex: max(1, (fraction * 100).round()),
                    child: Tooltip(
                      message: '${entry.key}: ${entry.value}',
                      child: ColoredBox(color: color),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          // Legend
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s4,
            children: distribution.entries.map((entry) {
              final color = _statusColors[entry.key] ??
                  AppColors.lightTextTertiary.withAlpha(100);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.key} (${entry.value})',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Priority distribution section (donut chart)
// ---------------------------------------------------------------------------

class _PriorityDistributionSection extends StatelessWidget {
  final Map<String, int> distribution;

  const _PriorityDistributionSection({required this.distribution});

  static const _priorityColors = <String, Color>{
    'High': AppColors.error,
    'Medium': AppColors.warning,
    'Low': AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final total = distribution.values.fold<int>(0, (sum, c) => sum + c);

    final segments = <_DonutSegment>[];
    double startAngle = -pi / 2;
    distribution.forEach((label, count) {
      final sweep = total > 0 ? 2 * pi * count / total : 0.0;
      segments.add(
        _DonutSegment(
          color: _priorityColors[label] ??
              AppColors.lightTextTertiary.withAlpha(100),
          startAngle: startAngle,
          sweepAngle: sweep,
          label: label,
          value: count,
        ),
      );
      startAngle += sweep;
    });

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.priorityDistribution ?? 'Priority Distribution',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Semantics(
                  label: l10n?.donutChartSemanticLabel(
                        segments
                            .map((s) => '${s.label}: ${s.value}')
                            .join(', '),
                      ) ??
                      'Donut chart showing priority distribution: ${segments.map((s) => '${s.label}: ${s.value}').join(', ')}',
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      segments: segments,
                      centerColor: isDark
                          ? AppColors.darkCardBg
                          : AppColors.lightCardBg,
                    ),
                    child: Center(
                      child: Text(
                        total.toString(),
                        style: AppTextStyles.headline.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((seg) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: seg.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Expanded(
                            child: Text(
                              seg.label,
                              style: AppTextStyles.caption.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${seg.value}',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Data for one segment of the donut chart.
class _DonutSegment {
  final Color color;
  final double startAngle;
  final double sweepAngle;
  final String label;
  final int value;

  const _DonutSegment({
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
    required this.label,
    required this.value,
  });
}

/// Custom painter for a soft donut chart with small gaps between segments.
class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final Color centerColor;

  _DonutChartPainter({
    required this.segments,
    required this.centerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = min(size.width, size.height) / 2;
    final innerRadius = outerRadius * 0.62;

    // Small gap angle between segments for visual separation.
    const gapAngle = 0.04;

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.fill;

      final sweepWithGap =
          seg.sweepAngle > gapAngle * 2 ? seg.sweepAngle - gapAngle : seg.sweepAngle;
      final startWithGap = seg.startAngle + gapAngle / 2;

      final outerRect =
          Rect.fromCircle(center: center, radius: outerRadius);
      final innerRect =
          Rect.fromCircle(center: center, radius: innerRadius);

      final path = Path()
        ..arcTo(outerRect, startWithGap, sweepWithGap, false)
        ..arcTo(
          innerRect,
          startWithGap + sweepWithGap,
          -sweepWithGap,
          false,
        )
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

// ---------------------------------------------------------------------------
// Knowledge graph stats section
// ---------------------------------------------------------------------------

class _KnowledgeGraphSection extends StatelessWidget {
  final NoteStatistics stats;

  const _KnowledgeGraphSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return _WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.hub_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n?.knowledgeGraphStats ?? 'Knowledge Graph',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.link_outlined,
                  label: l10n?.totalLinks ?? 'Total Links',
                  value: '${stats.totalLinks}',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  icon: Icons.note_outlined,
                  label: l10n?.notesWithLinks ?? 'Notes with links',
                  value: '${stats.notesWithLinks}',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MiniStat(
                  icon: Icons.scatter_plot_outlined,
                  label: l10n?.orphanedNotesCount(stats.orphanedNotes) ??
                      '${stats.orphanedNotes} orphaned',
                  value: '${stats.orphanedNotes}',
                ),
              ),
            ],
          ),
          if (stats.mostConnectedNote != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkInputFill
                    : AppColors.lightInputFill,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_outline,
                    size: 16,
                    color: AppColors.accentYellowText,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: Text(
                      l10n?.mostConnectedNote ?? 'Most Connected',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      stats.mostConnectedNote!.noteTitle.isEmpty
                          ? l10n?.untitled ?? 'Untitled'
                          : stats.mostConnectedNote!.noteTitle,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentYellowBg,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${stats.mostConnectedNote!.linkCount}',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentYellowText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: AppTextStyles.title.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
      ],
    );
  }
}
