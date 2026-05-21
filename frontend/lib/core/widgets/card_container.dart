import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// A soft, rounded card container matching the warm design system.
///
/// Replaces ad-hoc Container + BoxDecoration card patterns across the app.
/// Uses the design system radius, shadows, and spacing tokens automatically.
///
/// When [onTap] is provided, the card lifts slightly on press (shadow grows)
/// for tactile feedback. Uses [AnimatedContainer] for smooth transitions.
///
/// ```dart
/// CardContainer(
///   child: Text('Hello'),
/// )
///
/// // Tappable with lift animation
/// CardContainer(
///   onTap: () => context.push('/details'),
///   child: Text('Tap me'),
/// )
/// ```
class CardContainer extends StatefulWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderWidth;

  const CardContainer({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.radius,
    this.boxShadow,
    this.onTap,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  State<CardContainer> createState() => _CardContainerState();
}

class _CardContainerState extends State<CardContainer> {
  bool _isPressed = false;

  List<BoxShadow> _effectiveShadow(Brightness brightness) {
    final base = widget.boxShadow ?? AppShadows.smOf(brightness);
    if (!_isPressed || widget.onTap == null) return base;

    // On press: slightly stronger shadow for "lift" effect
    return [
      BoxShadow(
        color: AppColors.primary.withAlpha(12),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      ...base,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final effectiveColor =
        widget.color ?? (isDark ? AppColors.darkCardBg : AppColors.lightCardBg);
    final effectiveRadius = widget.radius ?? AppRadius.md;

    BoxDecoration decoration = BoxDecoration(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(effectiveRadius),
      boxShadow: _effectiveShadow(brightness),
    );

    if (widget.borderColor != null && widget.borderWidth > 0) {
      decoration = decoration.copyWith(
        border: Border.all(
          color: widget.borderColor!,
          width: widget.borderWidth,
        ),
      );
    }

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: widget.margin,
      padding: widget.padding,
      decoration: decoration,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(effectiveRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: container,
          ),
        ),
      );
    }

    return container;
  }
}
