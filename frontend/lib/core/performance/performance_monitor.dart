import 'package:flutter/foundation.dart';

/// Lightweight performance timing utility for tracking operation durations.
///
/// In debug mode ([kDebugMode] is true), operations that exceed the configured
/// threshold (default 500ms) are logged to the console with a [SLOW_OP] prefix.
/// In release mode, all methods are no-ops and the compiler tree-shakes the
/// entire class body away, adding zero overhead to production builds.
///
/// Usage:
///   PerformanceMonitor.instance.start('note_save');
///   await doSave();
///   PerformanceMonitor.instance.end('note_save');
///
/// For one-shot async timings:
///   final duration = await PerformanceMonitor.instance.track('sync_pull', () {
///     return syncEngine.pull();
///   });
class PerformanceMonitor {
  PerformanceMonitor._({this.slowThreshold = const Duration(milliseconds: 500)});

  /// Singleton instance.
  static final PerformanceMonitor instance = PerformanceMonitor._();

  /// Operations taking longer than this threshold are logged as slow in debug.
  final Duration slowThreshold;

  /// Active named timers: operation name -> start timestamp.
  final Map<String, Stopwatch> _timers = {};

  /// Start a named timer. No-op in release mode.
  void start(String name) {
    if (kReleaseMode) return;
    _timers[name] = Stopwatch()..start();
  }

  /// End a named timer and return the elapsed duration.
  ///
  /// In debug mode, logs the elapsed time. If the operation exceeded
  /// [slowThreshold], it is additionally logged with a [SLOW_OP] prefix.
  /// Returns null if no timer with [name] was running.
  Duration? end(String name) {
    if (kReleaseMode) return null;

    final sw = _timers.remove(name);
    if (sw == null) return null;
    sw.stop();
    final duration = sw.elapsed;

    debugPrint('[PERF] $name: ${duration.inMilliseconds}ms');
    if (duration > slowThreshold) {
      debugPrint(
        '[SLOW_OP] $name took ${duration.inMilliseconds}ms '
        '(threshold: ${slowThreshold.inMilliseconds}ms)',
      );
    }
    return duration;
  }

  /// Measure the duration of an async [action] under the given [name].
  ///
  /// Convenience method that wraps [start] and [end] around the action.
  /// Returns the result of [action].
  Future<T> track<T>(String name, Future<T> Function() action) async {
    if (kReleaseMode) return action();
    start(name);
    try {
      return await action();
    } finally {
      end(name);
    }
  }

  /// Whether a timer with the given [name] is currently running.
  /// Always returns false in release mode.
  bool isRunning(String name) {
    if (kReleaseMode) return false;
    return _timers.containsKey(name);
  }

  /// Cancel a running timer without logging. No-op if not running.
  void cancel(String name) {
    if (kReleaseMode) return;
    _timers.remove(name);
  }

  /// Remove all running timers. Useful in tests to avoid cross-test leaks.
  void reset() {
    if (kReleaseMode) return;
    _timers.clear();
  }
}
