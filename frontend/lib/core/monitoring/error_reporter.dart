import 'package:flutter/foundation.dart';

/// Lightweight error reporting service.
///
/// Captures Flutter framework errors and uncaught async errors via
/// [runZonedGuarded]. In debug mode errors are printed to the console.
/// In production this could be wired to a remote error tracking service
/// (e.g. Sentry) without changing call-sites.
class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._();
  factory ErrorReporter() => _instance;
  ErrorReporter._();

  /// Install global error handlers.
  ///
  /// Call once before [runApp] in `main()`.
  void init() {
    FlutterError.onError = (details) {
      reportFlutterError(details);
    };
  }

  /// Report a caught error with its stack trace.
  ///
  /// [context] is an optional human-readable label (e.g. "sync_push",
  /// "note_save") to make logs easier to grep.
  void reportError(Object error, StackTrace stackTrace, {String? context}) {
    final prefix = context != null ? '[ERROR] $context' : '[ERROR]';
    debugPrint('$prefix: $error');
    debugPrint('[STACK] $stackTrace');
  }

  /// Report a Flutter framework error captured by [FlutterError.onError].
  void reportFlutterError(FlutterErrorDetails details) {
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    debugPrint('[STACK] ${details.stack}');
  }
}
