import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A compact colored chip/tag matching the warm design system.
///
/// Used for tags, status badges, categories, and property indicators.
/// Renders a pill-shaped container with tinted background and optional icon.
///
/// ```dart
/// TagChip(label: 'Important', color: AppColors.accentPeach)
/// TagChip(label: 'Done', icon: Icons.check_circle, color: AppColors.success)
/// ```
class TagChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final TextStyle? textStyle;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
    this.selected = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipColor = color ?? theme.colorScheme.primary;

    final bgColor = selected
        ? chipColor.withValues(alpha: 0.25)
        : chipColor.withValues(alpha: isDark ? 0.15 : 0.1);

    final borderColor = chipColor.withValues(alpha: selected ? 0.4 : 0.2);

    final textColor = selected
        ? chipColor
        : chipColor.withValues(alpha: isDark ? 0.9 : 0.8);

    final effectiveTextStyle = (textStyle ?? AppTextStyles.caption).copyWith(
      color: textColor,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    final child = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: AppSpacing.s4),
          ],
          Text(label, style: effectiveTextStyle),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }
    return child;
  }
}
