/// Version changelog entries and the current application version.
///
/// Used by the "What's New" dialog to display highlights when the app
/// is updated to a new version. Entries are keyed by version string.
class Changelog {
  Changelog._();

  /// The current application version. Compared against the value stored
  /// in SharedPreferences to detect first launch after an update.
  static const kCurrentVersion = '2.4.0';

  /// Maps version strings to a list of brief feature descriptions.
  ///
  /// Only major/minor versions are included (patch versions are omitted
  /// unless they contain user-visible changes). The order of entries
  /// within each list reflects the order they should be displayed.
  static const Map<String, List<String>> entries = {
    '1.0.0': [
      'Core note-taking with rich text and Markdown support',
      'End-to-end encryption with XChaCha20-Poly1305',
      'Local-first architecture with offline access',
      'Cross-platform sync with version history',
      'Full-text search with Chinese language support',
    ],
    '1.1.0': [
      'Rich widgets: tables, callouts, code blocks',
      'Sync progress indicator and background sync',
      'CI/CD pipeline for automated builds',
      'Platform-specific polish and performance tuning',
    ],
    '1.2.0': [
      'Trash screen with soft-delete and restore',
      'Batch operations on notes',
      'Table editing in rich text mode',
      'Accessibility improvements and screen reader support',
      'Real-time collaboration sharing UI',
    ],
    '1.4.0': [
      'Backend security hardening with Redis rate limiting',
      'SQLCipher encryption for local database',
      'Formatting toolbar redesign',
      'Notes list performance optimization',
      'Tooltips with keyboard shortcuts',
    ],
    '2.0.0': [
      'Global error boundary for crash recovery',
      'Offline indicator banner across all screens',
      'Notification preferences screen',
      'What\'s New dialog on app updates',
      'Improved error handling throughout the app',
    ],
    '2.1.0': [
      'Anthropic LLM provider integration',
      'Auth and sync reliability improvements',
      'Blank screen on launch fix',
    ],
    '2.2.0': [
      'Stripe production billing integration',
      'Push notifications with Firebase',
      'Android compileSdk 36 with desugaring',
      'CI/CD pipeline hardening and automated builds',
    ],
    '2.3.0': [
      'Pastel palette design system with Phosphor icons',
      'Centralized color and icon theming',
      'APK size optimization with split-per-ABI builds',
      'Security hardening: SSRF, prompt injection, quota race',
      'Publish data encrypted at rest',
    ],
    '2.4.0': [
      'Onboarding flow reliability fix',
      'Specific, actionable error messages throughout the app',
      'Complete localization for Chinese, Japanese, and Korean',
      'Full color and icon theme migration',
      'Redesigned app icon',
    ],
  };
}
