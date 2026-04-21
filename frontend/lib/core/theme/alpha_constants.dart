/// Named alpha constants for consistent overlay and tint opacity values.
///
/// Use these instead of raw integer literals in `Color.withAlpha(...)` calls
/// to make the intent of each opacity level self-documenting.
class AppAlpha {
  AppAlpha._();

  /// Very faint overlays (e.g. splash highlight).
  static const int subtle = 15;

  /// Light dividers and tap feedback.
  static const int light = 25;

  /// Medium overlays (e.g. swipe background tint).
  static const int medium = 40;

  /// Prominent overlays (e.g. streaming indicator background).
  static const int semiBold = 77;

  /// Strong overlays (e.g. selected card fill, tag chip background).
  static const int bold = 80;

  /// Very strong overlays (e.g. tag chip border).
  static const int heavy = 100;

  /// Near-opaque secondary text (e.g. date labels).
  static const int prominent = 115;

  /// Almost opaque body text (e.g. preview text).
  static const int nearOpaque = 153;
}
