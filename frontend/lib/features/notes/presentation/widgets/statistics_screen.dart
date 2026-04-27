import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ),
      body: statsAsync.when(
        data: (stats) {
          if (stats.totalNotes == 0) {
            return _EmptyState(l10n: l10n);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewCards(stats: stats, l10n: l10n),
                const SizedBox(height: 24),
                _WritingStreakCard(
                  streak: stats.writingStreak,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _MonthlyActivityChart(
                  notesByMonth: stats.notesByMonth,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _TopTagsSection(topTags: stats.topTags, l10n: l10n),
                const SizedBox(height: 24),
                _TopCollectionsSection(
                  topCollections: stats.topCollections,
                  totalNotes: stats.totalNotes,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _StatusDistributionSection(
                  distribution: stats.statusDistribution,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _PriorityDistributionSection(
                  distribution: stats.priorityDistribution,
                  l10n: l10n,
                ),
                const SizedBox(height: 24),
                _KnowledgeGraphSection(stats: stats, l10n: l10n),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  l10n?.failedToLoadNote ?? 'Error loading statistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n?.noStatistics ?? 'No statistics yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.createFirstNoteHint ??
                'Create your first note to see statistics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
            textAlign: TextAlign.center,
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
  final AppLocalizations? l10n;

  const _OverviewCards({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: Icons.description_outlined,
          label: l10n?.totalNotes ?? 'Total Notes',
          value: _formatNumber(stats.totalNotes),
          color: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.text_fields_outlined,
          label: l10n?.totalWords ?? 'Total Words',
          value: _formatNumber(stats.totalWords),
          color: Theme.of(context).colorScheme.tertiary,
        ),
        _StatCard(
          icon: Icons.analytics_outlined,
          label: l10n?.averageWords ?? 'Avg Words/Note',
          value: stats.averageWordsPerNote.toStringAsFixed(0),
          color: Theme.of(context).colorScheme.secondary,
        ),
        _StatCard(
          icon: Icons.calendar_month_outlined,
          label: l10n?.daysActive ?? 'Days Active',
          value: _formatNumber(
            stats.writingStreak.activeDaysLast30.length,
          ),
          subtitle: l10n?.last30Days ?? 'last 30 days',
          color: Theme.of(context).colorScheme.error,
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Writing streak card
// ---------------------------------------------------------------------------

class _WritingStreakCard extends StatelessWidget {
  final WritingStreak streak;
  final AppLocalizations? l10n;

  const _WritingStreakCard({required this.streak, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  color: streak.currentStreak > 0
                      ? Colors.orange
                      : colorScheme.onSurface.withAlpha(100),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.writingStreak ?? 'Writing Streak',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.currentStreak(streak.currentStreak) ??
                            'Current: ${streak.currentStreak} days',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.longestStreak(streak.longestStreak) ??
                            'Longest: ${streak.longestStreak} days',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                if (streak.currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${streak.currentStreak}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Streak calendar (last 30 days)
            _StreakCalendar(activeDays: streak.activeDaysLast30),
          ],
        ),
      ),
    );
  }
}

/// Compact 30-day calendar showing active days as colored squares.
class _StreakCalendar extends StatelessWidget {
  final Set<String> activeDays;

  const _StreakCalendar({required this.activeDays});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 29));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)?.last30Days ?? 'Last 30 days',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withAlpha(100),
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(30, (i) {
            final date = startDate.add(Duration(days: i));
            final key =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final isActive = activeDays.contains(key);
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
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
  final AppLocalizations? l10n;

  const _MonthlyActivityChart({
    required this.notesByMonth,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Build last 12 months list, including months with zero notes.
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.monthlyActivity ?? 'Monthly Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
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
                    barColor: colorScheme.primary,
                    labelColor: colorScheme.onSurface.withAlpha(150),
                    gridColor: colorScheme.onSurface.withAlpha(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for a simple bar chart with month labels.
class _BarChartPainter extends CustomPainter {
  final List<String> months;
  final Map<String, int> values;
  final double maxValue;
  final Color barColor;
  final Color labelColor;
  final Color gridColor;

  _BarChartPainter({
    required this.months,
    required this.values,
    required this.maxValue,
    required this.barColor,
    required this.labelColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (months.isEmpty || size.width <= 0 || size.height <= 0) return;

    final barAreaHeight = size.height - 20; // Reserve 20px for labels.
    final barWidth = (size.width - (months.length - 1) * 4) / months.length;
    final clampedBarWidth = barWidth.clamp(8.0, 40.0);

    // Draw horizontal grid lines.
    final gridPaint = Paint()..color = gridColor;
    for (int i = 0; i <= 4; i++) {
      final y = barAreaHeight * (1 - i / 4);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final barPaint = Paint()..color = barColor;
    final barRadius = Radius.circular(clampedBarWidth / 4);
    final labelStyle = TextStyle(color: labelColor, fontSize: 9);

    for (int i = 0; i < months.length; i++) {
      final count = values[months[i]] ?? 0;
      final barHeight = maxValue > 0 ? (count / maxValue) * barAreaHeight : 0.0;

      final x = i * (clampedBarWidth + 4);
      final y = barAreaHeight - barHeight;

      // Draw bar with rounded top.
      if (barHeight > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, clampedBarWidth, barHeight),
          topLeft: barRadius,
          topRight: barRadius,
        );
        canvas.drawRRect(rect, barPaint);
      }

      // Draw month label (only show "M" portion).
      final label = months[i].substring(5); // 'MM'
      final textSpan = TextSpan(text: label, style: labelStyle);
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
  final AppLocalizations? l10n;

  const _TopTagsSection({required this.topTags, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (topTags.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.topTags ?? 'Top Tags',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topTags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tag = topTags[index];
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        '${tag.noteCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onPrimaryContainer,
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
  final AppLocalizations? l10n;

  const _TopCollectionsSection({
    required this.topCollections,
    required this.totalNotes,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (topCollections.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxCount = topCollections.first.noteCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.topCollections ?? 'Top Collections',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...topCollections.map((col) {
              final percent = totalNotes > 0
                  ? (col.noteCount / totalNotes * 100).toStringAsFixed(0)
                  : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                          ),
                        ),
                        Text(
                          '${col.noteCount} ($percent%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? col.noteCount / maxCount : 0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.secondary,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status distribution section
// ---------------------------------------------------------------------------

class _StatusDistributionSection extends StatelessWidget {
  final Map<String, int> distribution;
  final AppLocalizations? l10n;

  const _StatusDistributionSection({
    required this.distribution,
    required this.l10n,
  });

  // Color mapping for status values.
  static const _statusColors = {
    'Todo': Colors.blue,
    'In Progress': Colors.amber,
    'Done': Colors.green,
    'Blocked': Colors.red,
    'Cancelled': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = distribution.values.fold<int>(0, (sum, c) => sum + c);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.statusDistribution ?? 'Status Distribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Stacked horizontal bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: distribution.entries.map((entry) {
                    final fraction = total > 0 ? entry.value / total : 0.0;
                    final color = _statusColors[entry.key] ??
                        colorScheme.onSurface.withAlpha(100);
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
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: distribution.entries.map((entry) {
                final color = _statusColors[entry.key] ??
                    colorScheme.onSurface.withAlpha(100);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.key} (${entry.value})',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Priority distribution section (donut chart)
// ---------------------------------------------------------------------------

class _PriorityDistributionSection extends StatelessWidget {
  final Map<String, int> distribution;
  final AppLocalizations? l10n;

  const _PriorityDistributionSection({
    required this.distribution,
    required this.l10n,
  });

  static const _priorityColors = {
    'High': Colors.red,
    'Medium': Colors.amber,
    'Low': Colors.blue,
  };

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = distribution.values.fold<int>(0, (sum, c) => sum + c);

    // Build segments for the donut painter.
    final segments = <_DonutSegment>[];
    double startAngle = -pi / 2; // Start from top.
    distribution.forEach((label, count) {
      final sweep = total > 0 ? 2 * pi * count / total : 0.0;
      segments.add(
        _DonutSegment(
          color: _priorityColors[label] ?? colorScheme.onSurface.withAlpha(100),
          startAngle: startAngle,
          sweepAngle: sweep,
          label: label,
          value: count,
        ),
      );
      startAngle += sweep;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.priorityDistribution ?? 'Priority Distribution',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
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
                        centerColor: theme.cardColor,
                      ),
                      child: Center(
                        child: Text(
                          total.toString(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments.map((seg) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: seg.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                seg.label,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              '${seg.value}',
                              style: theme.textTheme.bodySmall?.copyWith(
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

/// Custom painter for a donut chart.
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
    final innerRadius = outerRadius * 0.6;

    for (final seg in segments) {
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.fill;

      final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
      final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

      final path = Path()
        ..arcTo(outerRect, seg.startAngle, seg.sweepAngle, false)
        ..arcTo(
          innerRect,
          seg.startAngle + seg.sweepAngle,
          -seg.sweepAngle,
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
  final AppLocalizations? l10n;

  const _KnowledgeGraphSection({required this.stats, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n?.knowledgeGraphStats ?? 'Knowledge Graph',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.link_outlined,
                    label: l10n?.totalLinks ?? 'Total Links',
                    value: '${stats.totalLinks}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.note_outlined,
                    label: l10n?.notesWithLinks ?? 'Notes with links',
                    value: '${stats.notesWithLinks}',
                  ),
                ),
                const SizedBox(width: 16),
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
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 16,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n?.mostConnectedNote ?? 'Most Connected',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      stats.mostConnectedNote!.noteTitle.isEmpty
                          ? l10n?.untitled ?? 'Untitled'
                          : stats.mostConnectedNote!.noteTitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${stats.mostConnectedNote!.linkCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );
  }
}
