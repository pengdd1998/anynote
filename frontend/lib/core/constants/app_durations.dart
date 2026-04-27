/// Commonly used durations across the app.
class AppDurations {
  AppDurations._();

  /// Very short animation duration (100 ms).
  static const veryShortAnimation = Duration(milliseconds: 100);

  /// Short animation duration (200 ms).
  static const shortAnimation = Duration(milliseconds: 200);

  /// Medium animation duration (250 ms).
  static const mediumAnimation = Duration(milliseconds: 250);

  /// Standard animation duration (300 ms).
  static const animation = Duration(milliseconds: 300);

  /// Long animation duration (400 ms).
  static const longAnimation = Duration(milliseconds: 400);

  /// Debounce duration for text input (300 ms).
  static const debounce = Duration(milliseconds: 300);

  /// Long debounce for search input (500 ms).
  static const searchDebounce = Duration(milliseconds: 500);

  /// Debounce duration for typing-heavy inputs (1 s).
  static const debounceTyping = Duration(seconds: 1);

  /// Auto-save delay after edits (1 s).
  static const autoSaveDelay = Duration(seconds: 1);

  /// Duration for snackbars and brief toasts (2 s).
  static const snackbarDuration = Duration(seconds: 2);

  /// Duration for error messages that need more reading time (4 s).
  static const errorDisplayDuration = Duration(seconds: 4);
}
