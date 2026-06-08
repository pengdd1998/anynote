import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Statistics tracked per operation name.
class _OpStats {
  int count = 0;
  Duration total = Duration.zero;
  Duration max = Duration.zero;
}

/// Simple performance monitor for tracking operation durations.
///
/// Logs slow operations via [debugPrint], aggregates per-operation statistics,
/// and optionally monitors frame timings via [FlutterBinding.addTimingsCallback].
class PerformanceMonitor {
  PerformanceMonitor._()
      : _timers = {},
        _stats = {},
        slowThreshold = const Duration(milliseconds: 500);

  /// Singleton instance.
  static final PerformanceMonitor instance = PerformanceMonitor._();

  final Map<String, Stopwatch> _timers;

  /// Per-operation aggregated statistics.
  final Map<String, _OpStats> _stats;

  /// Threshold beyond which an operation is considered slow.
  final Duration slowThreshold;

  /// Whether frame-level monitoring has been registered.
  bool _frameMonitoringActive = false;

  // ---------------------------------------------------------------------------
  // Manual timers
  // ---------------------------------------------------------------------------

  /// Start a timer with the given [name].
  void start(String name) {
    _timers[name] = Stopwatch()..start();
  }

  /// Whether a timer with [name] is currently running.
  bool isRunning(String name) => _timers.containsKey(name);

  /// End the timer [name] and return its duration, or null if not running.
  ///
  /// Logs a warning via [debugPrint] when the duration exceeds
  /// [slowThreshold]. Aggregates count / total / max statistics per name.
  /// Removes the completed timer from the internal map.
  Duration? end(String name) {
    final sw = _timers.remove(name);
    if (sw == null) return null;
    sw.stop();
    final elapsed = sw.elapsed;

    // Aggregate statistics.
    final stats = _stats.putIfAbsent(name, () => _OpStats());
    stats.count++;
    stats.total += elapsed;
    if (elapsed > stats.max) stats.max = elapsed;

    // Log slow operations in debug mode.
    if (elapsed > slowThreshold) {
      debugPrint(
        '[PerformanceMonitor] SLOW: "$name" took '
        '${elapsed.inMilliseconds} ms '
        '(threshold: ${slowThreshold.inMilliseconds} ms)',
      );
    }

    return elapsed;
  }

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  /// Returns aggregated statistics for [name], or `null` if never recorded.
  ///
  /// The returned map contains:
  /// - `count` (int) -- number of completed operations
  /// - `totalMs` (int) -- total elapsed milliseconds
  /// - `avgMs` (double) -- average milliseconds per operation
  /// - `maxMs` (int) -- slowest single operation in milliseconds
  Map<String, dynamic>? statsFor(String name) {
    final s = _stats[name];
    if (s == null || s.count == 0) return null;
    return {
      'count': s.count,
      'totalMs': s.total.inMilliseconds,
      'avgMs': s.total.inMilliseconds / s.count,
      'maxMs': s.max.inMilliseconds,
    };
  }

  // ---------------------------------------------------------------------------
  // Frame-level monitoring
  // ---------------------------------------------------------------------------

  /// Register a frame-timings callback that logs janky frames (those whose
  /// build time exceeds [slowThreshold]).
  ///
  /// Safe to call multiple times; only one callback is ever registered.
  void startFrameMonitoring() {
    if (_frameMonitoringActive) return;
    _frameMonitoringActive = true;

    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final frame in timings) {
        final buildDuration = frame.buildDuration;
        final rasterDuration = frame.rasterDuration;
        final totalDuration = Duration(
          microseconds:
              buildDuration.inMicroseconds + rasterDuration.inMicroseconds,
        );
        if (totalDuration > slowThreshold) {
          debugPrint(
            '[PerformanceMonitor] JANKY FRAME: build '
            '${buildDuration.inMilliseconds} ms, raster '
            '${rasterDuration.inMilliseconds} ms, total '
            '${totalDuration.inMilliseconds} ms',
          );
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Clear all running timers and aggregated statistics.
  void reset() {
    _timers.clear();
    _stats.clear();
  }
}
