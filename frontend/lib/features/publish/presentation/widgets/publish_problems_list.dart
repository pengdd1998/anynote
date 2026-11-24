import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/publish_rules.dart';

/// Shows what the server found wrong with a post: the problems that stop it
/// from being published, then the advice. Used both while the user is still
/// writing (pre-publish check) and after a rejected submit.
class PublishProblemsList extends StatelessWidget {
  const PublishProblemsList({
    super.key,
    this.blocking = const [],
    this.advisory = const [],
    this.checking = false,
  });

  /// Findings that stop the post from being published.
  final List<PublishProblem> blocking;

  /// Findings the user may ignore.
  final List<PublishProblem> advisory;

  /// A check is running and nothing has come back yet.
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (blocking.isEmpty && advisory.isEmpty && !checking) {
      return const SizedBox.shrink();
    }

    final blocks = <Widget>[];
    if (blocking.isNotEmpty) {
      blocks.add(_Section(
        icon: AppIcons.errorOutline,
        color: theme.colorScheme.error,
        heading: l10n.publishFixBeforePublishing,
        problems: blocking,
      ));
    }
    if (advisory.isNotEmpty) {
      blocks.add(_Section(
        icon: AppIcons.lightbulb,
        color: theme.colorScheme.tertiary,
        heading: l10n.publishSuggestions,
        problems: advisory,
      ));
    }
    if (blocks.isEmpty) {
      blocks.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(l10n.publishChecking, style: theme.textTheme.bodySmall),
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          blocks[i],
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.heading,
    required this.problems,
  });

  final IconData icon;
  final Color color;
  final String heading;
  final List<PublishProblem> problems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                heading,
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          for (final problem in problems)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 22),
              child: Text(
                problem.message,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
        ],
      ),
    );
  }
}

/// `12/20` next to a field label, turning red once the draft is over the
/// platform's limit — the one rule an editor can enforce without asking.
class LengthCounter extends StatelessWidget {
  const LengthCounter({super.key, required this.length, required this.max});

  final int length;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = length > max;
    // Warn before the limit so there is room to finish a sentence.
    final near = !over && length >= max * 0.9;
    final color = over
        ? theme.colorScheme.error
        : near
            ? theme.colorScheme.tertiary
            : theme.colorScheme.onSurfaceVariant;
    return Text(
      '$length/$max',
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
