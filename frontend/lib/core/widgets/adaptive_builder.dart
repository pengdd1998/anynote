import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';

/// A widget that builds different layouts based on the current screen width.
///
/// This is a lighter-weight alternative to [AdaptiveScaffold] for cases
/// where you need inline responsive decisions without a full scaffold.
///
/// Three builders are provided:
/// - [compactBuilder] -- called when width < 600dp (phone)
/// - [mediumBuilder] -- called when width >= 600dp and < 1024dp (tablet)
/// - [expandedBuilder] -- called when width >= 1024dp (desktop)
///
/// If a builder is null, the next smaller available builder is used as fallback.
/// [compactBuilder] is required and serves as the ultimate fallback.
///
/// Usage:
/// ```dart
/// AdaptiveBuilder(
///   compactBuilder: (context) => MobileLayout(),
///   mediumBuilder: (context) => TabletLayout(),
///   expandedBuilder: (context) => DesktopLayout(),
/// )
/// ```
class AdaptiveBuilder extends StatelessWidget {
  /// Builder for compact (phone) layouts. Required -- serves as fallback.
  final WidgetBuilder compactBuilder;

  /// Builder for medium (tablet) layouts. Falls back to [compactBuilder].
  final WidgetBuilder? mediumBuilder;

  /// Builder for expanded (desktop) layouts. Falls back to [mediumBuilder],
  /// then [compactBuilder].
  final WidgetBuilder? expandedBuilder;

  const AdaptiveBuilder({
    super.key,
    required this.compactBuilder,
    this.mediumBuilder,
    this.expandedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (Breakpoints.isExpanded(width) && expandedBuilder != null) {
      return expandedBuilder!(context);
    }
    if (!Breakpoints.isCompact(width) && mediumBuilder != null) {
      return mediumBuilder!(context);
    }
    return compactBuilder(context);
  }
}

/// A widget that shows or hides its child based on the current screen width.
///
/// Useful for platform-aware UI elements like sidebar controls that only
/// make sense on desktop, or mobile-specific action buttons.
///
/// Usage:
/// ```dart
/// AdaptiveVisibility(
///   visibleWhen: (width) => Breakpoints.isExpanded(width),
///   child: SidebarControls(),
/// )
/// ```
class AdaptiveVisibility extends StatelessWidget {
  /// Predicate that receives the current screen width and returns whether
  /// the child should be visible.
  final bool Function(double width) visibleWhen;

  /// The widget to show or hide.
  final Widget child;

  const AdaptiveVisibility({
    super.key,
    required this.visibleWhen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Visibility(
      visible: visibleWhen(width),
      maintainState: false,
      maintainSize: false,
      maintainAnimation: false,
      child: child,
    );
  }
}

/// A widget that provides platform-aware padding around its child.
///
/// Adds extra horizontal padding on desktop/tablet to prevent content from
/// stretching too wide on large screens. On compact screens, uses minimal
/// horizontal padding to maximize usable space.
///
/// Usage:
/// ```dart
/// AdaptivePadding(
///   child: Text('Content that should not stretch too wide'),
/// )
/// ```
class AdaptivePadding extends StatelessWidget {
  /// The widget to wrap with adaptive padding.
  final Widget child;

  /// Maximum horizontal content width on expanded layouts.
  /// Content is centered when the screen is wider than this.
  final double maxContentWidth;

  const AdaptivePadding({
    super.key,
    required this.child,
    this.maxContentWidth = 840,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (Breakpoints.isExpanded(width)) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
    }

    if (!Breakpoints.isCompact(width)) {
      // Tablet: add moderate horizontal padding.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: child,
      );
    }

    // Phone: minimal padding.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}
