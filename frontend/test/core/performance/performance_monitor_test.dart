import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/monitoring/performance_monitor.dart';

void main() {
  late PerformanceMonitor monitor;

  setUp(() {
    monitor = PerformanceMonitor.instance;
    // Clear any timers left over from previous tests.
    monitor.reset();
  });

  tearDown(() {
    monitor.reset();
  });

  group('PerformanceMonitor singleton', () {
    test('instance is always the same object', () {
      final a = PerformanceMonitor.instance;
      final b = PerformanceMonitor.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('start and end', () {
    test('start creates a running timer', () {
      monitor.start('test-op');
      expect(monitor.isRunning('test-op'), isTrue);
    });

    test('isRunning returns false for non-existent timer', () {
      expect(monitor.isRunning('nonexistent'), isFalse);
    });

    test('end returns a Duration for an existing timer', () {
      monitor.start('timed-op');
      // Let a tiny amount of time pass
      final duration = monitor.end('timed-op');

      expect(duration, isNotNull);
      expect(duration!.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('end returns null for non-existent timer', () {
      final duration = monitor.end('nonexistent');
      expect(duration, isNull);
    });

    test('end removes the timer so isRunning returns false', () {
      monitor.start('removable');
      expect(monitor.isRunning('removable'), isTrue);

      monitor.end('removable');
      expect(monitor.isRunning('removable'), isFalse);
    });

    test('end on already-ended timer returns null', () {
      monitor.start('double-end');
      monitor.end('double-end');
      final second = monitor.end('double-end');
      expect(second, isNull);
    });

    test('multiple timers can run simultaneously', () {
      monitor.start('timer-a');
      monitor.start('timer-b');
      monitor.start('timer-c');

      expect(monitor.isRunning('timer-a'), isTrue);
      expect(monitor.isRunning('timer-b'), isTrue);
      expect(monitor.isRunning('timer-c'), isTrue);

      monitor.end('timer-b');
      expect(monitor.isRunning('timer-b'), isFalse);
      expect(monitor.isRunning('timer-a'), isTrue);
    });

    test('restarting a timer with the same name replaces it', () {
      monitor.start('restart');
      monitor.start('restart');

      // Only one timer with that name should exist
      final duration = monitor.end('restart');
      expect(duration, isNotNull);
      expect(monitor.isRunning('restart'), isFalse);
    });

    test('measures elapsed time correctly', () {
      monitor.start('measure');

      // Run a known-duration operation
      final sw = Stopwatch()..start();
      // Busy loop for a measurable amount of time
      while (sw.elapsedMilliseconds < 10) {
        // busy wait
      }
      sw.stop();

      final duration = monitor.end('measure');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, greaterThanOrEqualTo(10));
    });
  });

  group('track', () {
    test('returns the result of the action', () async {
      monitor.start('pre-track');

      final result = await monitor.track<int>('add-op', () async {
        return 42;
      });

      expect(result, 42);
      expect(monitor.isRunning('add-op'), isFalse);
    });

    test('measures the duration of the action', () async {
      final result = await monitor.track<String>('slow-op', () async {
        await Future.delayed(const Duration(milliseconds: 20));
        return 'done';
      });

      expect(result, 'done');
      // Timer should be removed after track completes
      expect(monitor.isRunning('slow-op'), isFalse);
    });

    test('cleans up timer even if action throws', () async {
      try {
        await monitor.track<void>('failing-op', () async {
          throw Exception('boom');
        });
      } catch (_) {
        // Expected
      }

      // Timer should be cleaned up by the finally block
      expect(monitor.isRunning('failing-op'), isFalse);
    });

    test('propagates the exception from the action', () async {
      expect(
        () => monitor.track<void>('error-op', () async {
          throw StateError('test error');
        }),
        throwsA(isA<StateError>()),
      );
    });

    test('works with null return type', () async {
      await monitor.track<void>('void-op', () async {
        // no return
      });

      // Timer should be cleaned up after track completes
      expect(monitor.isRunning('void-op'), isFalse);
    });
  });

  group('cancel', () {
    test('removes a running timer without logging', () {
      monitor.start('cancel-me');
      expect(monitor.isRunning('cancel-me'), isTrue);

      monitor.cancel('cancel-me');
      expect(monitor.isRunning('cancel-me'), isFalse);
    });

    test('cancel non-existent timer does nothing', () {
      // Should not throw
      monitor.cancel('nonexistent');
    });

    test('cancel does not return a duration', () {
      monitor.start('cancel-test');
      monitor.cancel('cancel-test');

      // Verify the timer is truly gone
      expect(monitor.isRunning('cancel-test'), isFalse);
    });
  });

  group('reset', () {
    test('removes all running timers', () {
      monitor.start('a');
      monitor.start('b');
      monitor.start('c');

      expect(monitor.isRunning('a'), isTrue);
      expect(monitor.isRunning('b'), isTrue);
      expect(monitor.isRunning('c'), isTrue);

      monitor.reset();

      expect(monitor.isRunning('a'), isFalse);
      expect(monitor.isRunning('b'), isFalse);
      expect(monitor.isRunning('c'), isFalse);
    });

    test('reset on empty monitor does nothing', () {
      // Should not throw
      monitor.reset();
    });

    test('monitor works correctly after reset', () {
      monitor.start('pre-reset');
      monitor.reset();

      monitor.start('post-reset');
      expect(monitor.isRunning('post-reset'), isTrue);

      final duration = monitor.end('post-reset');
      expect(duration, isNotNull);
    });
  });

  group('slowThreshold', () {
    test('default threshold is 500ms', () {
      expect(
        monitor.slowThreshold,
        const Duration(milliseconds: 500),
      );
    });

    test('threshold is accessible', () {
      // The threshold is set in the private constructor and exposed as final.
      expect(monitor.slowThreshold.inMilliseconds, greaterThan(0));
    });
  });
}
