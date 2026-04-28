/// Screen-size breakpoints for responsive layout decisions.
///
/// These constants are used by [AdaptiveScaffold], [MasterDetailLayout],
/// and any widget that needs to adapt its layout based on screen width.
///
/// The values follow Material Design 3 adaptive layout guidance:
/// - **Compact** (< 600dp): phone handsets in portrait
/// - **Medium** (600-1023dp): tablets in portrait, small desktop windows
/// - **Expanded** (>= 1024dp): desktop and large tablets in landscape
class Breakpoints {
  Breakpoints._();

  /// Width below which the layout is "compact" (phone handset).
  static const double compact = 600;

  /// Width at or above which the layout is "expanded" (desktop).
  static const double expanded = 1024;

  /// Returns true for compact (phone) layouts: width < [compact].
  static bool isCompact(double width) => width < compact;

  /// Returns true for medium (tablet) layouts: [compact] <= width < [expanded].
  static bool isMedium(double width) => width >= compact && width < expanded;

  /// Returns true for expanded (desktop) layouts: width >= [expanded].
  static bool isExpanded(double width) => width >= expanded;

  /// Returns true when the width is large enough for side-by-side panes.
  ///
  /// This is the threshold used by [MasterDetailLayout] to decide between
  /// stacked and side-by-side layouts.
  static bool isSideBySide(double width) => width >= compact;
}
