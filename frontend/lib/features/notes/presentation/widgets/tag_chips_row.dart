import 'package:flutter/material.dart';

import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';

/// Displays up to 3 tag chips with indigo badge styling.
///
/// Matches the design mockup: small indigo text badges with
/// indigo-50 background and bold indigo-600 text.
class TagChipsRow extends StatelessWidget {
  /// Tags to display. Only the first 3 are shown.
  final List<Tag> tags;

  const TagChipsRow({super.key, required this.tags});

  @override
  Widget build(BuildContext context) {
    final displayTags = tags.take(3).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: displayTags.map<Widget>((tag) {
        return Semantics(
          label: A11yUtils.semanticLabelForTag(name: tag.plainName ?? '...'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.indigo50,
              borderRadius: BorderRadius.circular(AppRadius.xxs),
            ),
            child: Text(
              tag.plainName ?? '...',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
