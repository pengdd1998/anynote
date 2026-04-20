import 'package:flutter/foundation.dart';

/// Callback type for integrating a remote error reporting service
/// (e.g. Sentry, Crashlytics) with [ErrorReporter].
typedef ErrorReporterCallback = void Function(
  Object error,
  StackTrace stackTrace, {
  String? context,
});

/// Lightweight error reporting service.
///
/// Captures Flutter framework errors and uncaught async errors via
/// [runZonedGuarded]. In debug mode errors are printed to the console.
/// Wire [ErrorReporterCallback] via [init] to forward errors to a remote
/// tracking service (e.g. Sentry) without changing call-sites.
class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._();

  /// Singleton accessor.
  static ErrorReporter get instance => _instance;

  /// Legacy factory – returns the singleton.
  factory ErrorReporter() => _instance;

  ErrorReporter._();

  ErrorReporterCallback? _callback;
  bool _enabled = false;

  /// Install global error handlers.
  ///
  /// Call once before [runApp] in `main()`. Optionally provide a
  /// [remoteReporter] callback to forward errors to an external service.
  void init({ErrorReporterCallback? remoteReporter, bool enabled = true}) {
    _callback = remoteReporter;
    _enabled = enabled;
    FlutterError.onError = (details) {
      reportFlutterError(details);
    };
  }

  /// Report a caught error with its stack trace.
  ///
  /// [context] is an optional human-readable label (e.g. "sync_push",
  /// "note_save") to make logs easier to grep.
  void reportError(Object error, StackTrace stackTrace, {String? context}) {
    if (!_enabled) return;
    final prefix = context != null ? '[ERROR] $context' : '[ERROR]';
    debugPrint('$prefix: $error');
    debugPrint('[STACK] $stackTrace');
    _callback?.call(error, stackTrace, context: context);
  }

  /// Report a Flutter framework error captured by [FlutterError.onError].
  void reportFlutterError(FlutterErrorDetails details) {
    if (!_enabled) return;
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    debugPrint('[STACK] ${details.stack}');
    _callback?.call(
      details.exception,
      details.stack ?? StackTrace.empty,
      context: 'flutter_error',
    );
  }
}
