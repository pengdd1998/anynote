import 'package:flutter/foundation.dart';

/// Lightweight performance timing utility.
///
/// Usage:
///   PerformanceMonitor.start('note_save');
///   await doSave();
///   PerformanceMonitor.end('note_save'); // prints [PERF] note_save: 42ms
class PerformanceMonitor {
  static final Map<String, DateTime> _timers = {};

  /// Start a named timer.
  static void start(String name) {
    _timers[name] = DateTime.now();
  }

  /// End a named timer and return the elapsed duration.
  ///
  /// Prints a debug log line with the elapsed milliseconds.
  /// Returns null if no timer with [name] was running.
  static Duration? end(String name) {
    final start = _timers.remove(name);
    if (start == null) return null;
    final duration = DateTime.now().difference(start);
    debugPrint('[PERF] $name: ${duration.inMilliseconds}ms');
    return duration;
  }
}
