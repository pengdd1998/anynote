/// How long the app waits before doing something — not how long anything
/// takes to move: animation durations are `AppAnimation`'s.
class AppDurations {
  AppDurations._();

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
