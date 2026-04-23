import 'package:flutter/material.dart';

import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/alpha_constants.dart';

/// Displays up to 3 tag chips with warm fill and border styling.
///
/// Extracted from `NotesListScreen._buildTagChips` for reuse across
/// list and grid note cards.
class TagChipsRow extends StatelessWidget {
  /// Tags to display. Only the first 3 are shown.
  final List<Tag> tags;

  const TagChipsRow({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayTags = tags.take(3).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: displayTags.map((tag) {
        return Semantics(
          label: A11yUtils.semanticLabelForTag(name: tag.plainName ?? '...'),
          child: Chip(
            label: Text(
              tag.plainName ?? '...',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withAlpha(AppAlpha.nearOpaque),
              ),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            side: BorderSide(
              color: colorScheme.outlineVariant.withAlpha(AppAlpha.heavy),
              width: 0.5,
            ),
            backgroundColor:
                colorScheme.surfaceContainerHighest.withAlpha(AppAlpha.bold),
          ),
        );
      }).toList(),
    );
  }
}
