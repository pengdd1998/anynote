import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../l10n/app_localizations.dart';
import 'writing_stats.dart';

/// A compact single-line bar showing writing statistics at the bottom of the
/// note editor. Displays word count, character count, reading time, line
/// count, and paragraph count.
///
/// The bar is designed to be ~32px tall with a semi-transparent background.
/// Statistics update in real-time (debounced by the caller).
class WritingStatsBar extends StatelessWidget {
  /// The computed writing statistics to display.
  final WritingStats stats;

  /// Whether the bar is currently visible (used for animated show/hide).
  final bool isVisible;

  /// Callback when the visibility toggle is tapped.
  final VoidCallback onToggleVisibility;

  const WritingStatsBar({
    super.key,
    required this.stats,
    required this.isVisible,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Caption color: warm muted tone matching the app theme.
    final captionColor =
        isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54);

    // Semi-transparent background.
    final backgroundColor = isDark
        ? const Color(0xFF1A1816).withValues(alpha: 0.85)
        : const Color(0xFFFFFDFB).withValues(alpha: 0.85);

    if (!isVisible) {
      // When hidden, show only the toggle button.
      return SafeArea(
        top: false,
        bottom: true,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 4),
            child: _buildToggleButton(context, captionColor),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF332E2B) : const Color(0xFFF0E8DF),
              width: 0.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Word count.
              Expanded(
                child: _StatChip(
                  label: l10n.wordCount(stats.wordCount),
                  color: captionColor,
                ),
              ),
              _StatDivider(color: captionColor),
              // Character count.
              Expanded(
                child: _StatChip(
                  label: l10n.charCount(stats.charCount),
                  color: captionColor,
                ),
              ),
              _StatDivider(color: captionColor),
              // Reading time.
              Expanded(
                child: _StatChip(
                  label: _formatReadingTime(l10n, stats),
                  color: captionColor,
                ),
              ),
              _StatDivider(color: captionColor),
              // Line count.
              Expanded(
                child: _StatChip(
                  label: l10n.lineCount(stats.lineCount),
                  color: captionColor,
                ),
              ),
              _StatDivider(color: captionColor),
              // Paragraph count.
              Expanded(
                child: _StatChip(
                  label: l10n.paragraphCount(stats.paragraphCount),
                  color: captionColor,
                ),
              ),
              // Toggle button.
              _buildToggleButton(context, captionColor),
            ],
          ),
        ),
      ),
    );
  }

  /// Toggle button to hide/show the stats bar.
  Widget _buildToggleButton(BuildContext context, Color color) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.toggleWritingStats,
      child: IconButton(
        icon: Icon(
          isVisible ? Icons.bar_chart : Icons.bar_chart_outlined,
          size: 16,
          color: color,
        ),
        tooltip: l10n.toggleWritingStats,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: onToggleVisibility,
      ),
    );
  }

  /// Format reading time as a human-readable string.
  String _formatReadingTime(AppLocalizations l10n, WritingStats stats) {
    final totalSeconds = stats.estimatedReadingTime.inSeconds;
    if (totalSeconds < 60) {
      return l10n.lessThan1Min;
    }
    final minutes = stats.estimatedReadingTime.inMinutes;
    return l10n.readingTime(minutes);
  }
}

/// A single stat label with animated transitions on value change.
class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.shortAnimation,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Text(
        label,
        key: ValueKey(label),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Thin vertical divider between stat chips.
class _StatDivider extends StatelessWidget {
  final Color color;

  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '|',
        style: TextStyle(
          color: color.withValues(alpha: 0.3),
          fontSize: 10,
        ),
      ),
    );
  }
}
