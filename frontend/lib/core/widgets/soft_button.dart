import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A soft-styled button matching the warm design system.
///
/// Provides variants for primary, secondary, ghost, and danger actions.
/// Includes a built-in loading state with a small spinner.
///
/// ```dart
/// SoftButton(
///   label: 'Save',
///   onPressed: _save,
///   loading: _isSaving,
/// )
///
/// SoftButton.danger(
///   label: 'Delete',
///   onPressed: _delete,
///   icon: Icons.delete_outline,
/// )
/// ```
class SoftButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final SoftButtonVariant variant;
  final bool expanded;

  const SoftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = SoftButtonVariant.primary,
    this.expanded = false,
  });

  const SoftButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = false,
  }) : variant = SoftButtonVariant.secondary;

  const SoftButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = false,
  }) : variant = SoftButtonVariant.ghost;

  const SoftButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = false,
  }) : variant = SoftButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    if (variant == SoftButtonVariant.ghost) {
      return _buildGhost(context);
    }

    final buttonStyle = _resolveStyle(context);

    Widget buttonChild = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.s4),
          ],
          Text(label),
        ],
      ],
    );

    if (expanded) {
      buttonChild = Center(child: buttonChild);
    }

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: buttonStyle,
      child: buttonChild,
    );
  }

  Widget _buildGhost(BuildContext context) {
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.s4),
                ],
                Text(label),
              ],
            ),
    );
  }

  ButtonStyle _resolveStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (variant) {
      case SoftButtonVariant.primary:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        );
      case SoftButtonVariant.secondary:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        );
      case SoftButtonVariant.danger:
        return FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        );
      case SoftButtonVariant.ghost:
        // handled above
        return const ButtonStyle();
    }
  }
}

enum SoftButtonVariant { primary, secondary, ghost, danger }
