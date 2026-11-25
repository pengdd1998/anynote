import 'package:flutter/material.dart';

import '../theme/app_animation.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A reusable empty state widget displayed when a list has no items.
///
/// Shows a warm icon badge in a tinted container, a title, an optional
/// subtitle, and an optional action button. It fades in.
///
/// Usage:
/// ```dart
/// EmptyState(
///   icon: AppIcons.noteAdd,
///   title: 'No notes yet',
///   subtitle: 'Create your first note',
///   actionLabel: 'New Note',
///   onAction: () => context.push('/notes/new'),
/// )
/// ```
class EmptyState extends StatefulWidget {
  /// Large icon displayed above the title.
  final IconData icon;

  /// Primary message (e.g. "No notes yet").
  final String title;

  /// Secondary explanation (e.g. "Create your first note").
  final String? subtitle;

  /// Label for the optional CTA button.
  final String? actionLabel;

  /// Callback when the CTA button is pressed.
  final VoidCallback? onAction;

  /// Optional accent background color for the icon badge.
  final Color? accentBg;

  /// Optional accent text/icon color.
  final Color? accentText;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accentBg,
    this.accentText,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    // Over in a single frame when "减少动画" is on (see ReduceMotionBinding).
    _fade = AnimationController(vsync: this, duration: AppAnimation.standard)
      ..forward();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentBg = widget.accentBg ?? AppColors.accentLavenderBg;
    final accentText = widget.accentText ?? AppColors.accentLavenderText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  widget.icon,
                  size: 32,
                  color: accentText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.title,
                style: AppTextStyles.title.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  widget.subtitle!,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonal(
                  onPressed: widget.onAction,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
