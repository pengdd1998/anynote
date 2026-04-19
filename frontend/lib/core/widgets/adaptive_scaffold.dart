import 'package:flutter/material.dart';

/// Responsive layout that shows different UI depending on screen width.
///
/// Three breakpoints are provided:
/// - **Phone**: width < 600 (mobile handsets)
/// - **Tablet**: width >= 600 and < 1024 (tablets and small desktop windows)
/// - **Desktop**: width >= 1024 (desktop and large tablets in landscape)
///
/// If no [tabletLayout] or [desktopLayout] is provided the widget falls back
/// to the next smaller layout. The [phoneLayout] is always required.
///
/// Usage:
/// ```dart
/// AdaptiveScaffold(
///   phoneLayout: MobileView(),
///   tabletLayout: TabletView(),
///   desktopLayout: DesktopView(),
/// )
/// ```
class AdaptiveScaffold extends StatelessWidget {
  /// Layout shown on phone-sized screens (< 600px).
  final Widget phoneLayout;

  /// Layout shown on tablet-sized screens (600-1023px). Falls back to
  /// [phoneLayout] if null.
  final Widget? tabletLayout;

  /// Layout shown on desktop-sized screens (>= 1024px). Falls back to
  /// [tabletLayout] if null, then to [phoneLayout].
  final Widget? desktopLayout;

  const AdaptiveScaffold({
    super.key,
    required this.phoneLayout,
    this.tabletLayout,
    this.desktopLayout,
  });

  /// Whether the current screen is phone-sized.
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  /// Whether the current screen is tablet-sized.
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1024;
  }

  /// Whether the current screen is desktop-sized.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context) && desktopLayout != null) {
      return desktopLayout!;
    }
    if (!isPhone(context) && tabletLayout != null) {
      return tabletLayout!;
    }
    return phoneLayout;
  }
}
