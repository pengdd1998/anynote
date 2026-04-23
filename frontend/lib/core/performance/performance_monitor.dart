import 'dart:async';

/// Simple performance monitor for tracking operation durations.
class PerformanceMonitor {
  PerformanceMonitor._()
      : _timers = {},
        slowThreshold = const Duration(milliseconds: 500);

  /// Singleton instance.
  static final PerformanceMonitor instance = PerformanceMonitor._();

  final Map<String, Stopwatch> _timers;

  /// Threshold beyond which an operation is considered slow.
  final Duration slowThreshold;

  /// Start a timer with the given [name].
  void start(String name) {
    _timers[name] = Stopwatch()..start();
  }

  /// Whether a timer with [name] is currently running.
  bool isRunning(String name) => _timers.containsKey(name);

  /// End the timer [name] and return its duration, or null if not running.
  Duration? end(String name) {
    final sw = _timers.remove(name);
    if (sw == null) return null;
    sw.stop();
    return sw.elapsed;
  }

  /// Track an async [action] under [name], returning its result.
  Future<T> track<T>(String name, Future<T> Function() action) async {
    start(name);
    try {
      return await action();
    } finally {
      end(name);
    }
  }

  /// Cancel a running timer without logging.
  void cancel(String name) {
    _timers.remove(name);
  }

  /// Reset all running timers.
  void reset() {
    _timers.clear();
  }
}
