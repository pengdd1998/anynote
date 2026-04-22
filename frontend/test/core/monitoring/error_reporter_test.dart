import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/monitoring/error_reporter.dart';

void main() {
  late ErrorReporter reporter;

  setUp(() {
    // ErrorReporter is a singleton, but we can re-initialize for each test.
    // Access the instance fresh each time.
    reporter = ErrorReporter.instance;
    // Reset by calling init with enabled: false first to clear state.
    reporter.init(enabled: false);
  });

  tearDown(() {
    // Ensure reporter is disabled after each test to avoid side effects.
    reporter.init(enabled: false);
  });

  group('ErrorReporter singleton', () {
    test('instance is always the same object', () {
      final a = ErrorReporter.instance;
      final b = ErrorReporter.instance;
      expect(identical(a, b), isTrue);
    });

    test('factory constructor returns the singleton', () {
      final a = ErrorReporter.instance;
      final b = ErrorReporter();
      expect(identical(a, b), isTrue);
    });
  });

  group('ErrorReporter.init', () {
    test('sets up FlutterError.onError handler', () {
      final originalHandler = FlutterError.onError;

      reporter.init(enabled: true);

      expect(FlutterError.onError, isNotNull);
      expect(identical(FlutterError.onError, originalHandler), isFalse);

      // Restore
      FlutterError.onError = originalHandler;
    });

    test('stores the remote callback', () {
      Object? capturedError;
      StackTrace? capturedStack;
      String? capturedContext;

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedError = error;
          capturedStack = stackTrace;
          capturedContext = context;
        },
      );

      // Trigger via reportError
      final testError = Exception('test');
      final testStack = StackTrace.current;
      reporter.reportError(testError, testStack, context: 'test_ctx');

      expect(capturedError, testError);
      expect(capturedStack, testStack);
      expect(capturedContext, 'test_ctx');
    });

    test('does not report when disabled', () {
      Object? capturedError;

      reporter.init(
        enabled: false,
        remoteReporter: (error, stackTrace, {context}) {
          capturedError = error;
        },
      );

      reporter.reportError(Exception('test'), StackTrace.empty);

      expect(capturedError, isNull);
    });
  });

  group('ErrorReporter.reportError', () {
    test('invokes callback with correct error and stack trace', () {
      Object? capturedError;
      StackTrace? capturedStack;

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedError = error;
          capturedStack = stackTrace;
        },
      );

      final error = StateError('test state error');
      final stack = StackTrace.current;
      reporter.reportError(error, stack);

      expect(capturedError, error);
      expect(capturedStack, stack);
    });

    test('invokes callback with context when provided', () {
      String? capturedContext;

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedContext = context;
        },
      );

      reporter.reportError(
        Exception('test'),
        StackTrace.empty,
        context: 'sync_push',
      );

      expect(capturedContext, 'sync_push');
    });

    test('invokes callback with null context when not provided', () {
      String? capturedContext = 'not-null-sentinel';

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedContext = context;
        },
      );

      reporter.reportError(Exception('test'), StackTrace.empty);

      expect(capturedContext, isNull);
    });

    test('does not invoke callback when disabled', () {
      bool callbackInvoked = false;

      reporter.init(
        enabled: false,
        remoteReporter: (error, stackTrace, {context}) {
          callbackInvoked = true;
        },
      );

      reporter.reportError(Exception('test'), StackTrace.empty);

      expect(callbackInvoked, isFalse);
    });

    test('handles multiple sequential reports', () {
      final capturedErrors = <Object>[];

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedErrors.add(error);
        },
      );

      reporter.reportError(Exception('first'), StackTrace.empty);
      reporter.reportError(Exception('second'), StackTrace.empty);
      reporter.reportError(Exception('third'), StackTrace.empty);

      expect(capturedErrors.length, 3);
    });

    test('handles various error types', () {
      final capturedErrors = <Object>[];

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedErrors.add(error);
        },
      );

      reporter.reportError(StateError('state'), StackTrace.empty);
      reporter.reportError(ArgumentError('arg'), StackTrace.empty);
      reporter.reportError(RangeError('range'), StackTrace.empty);
      reporter.reportError(Exception('generic'), StackTrace.empty);
      reporter.reportError('string error', StackTrace.empty);
      reporter.reportError(42, StackTrace.empty);

      expect(capturedErrors.length, 6);
    });
  });

  group('ErrorReporter.reportFlutterError', () {
    test('invokes callback with FlutterErrorDetails data', () {
      Object? capturedError;
      StackTrace? capturedStack;
      String? capturedContext;

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedError = error;
          capturedStack = stackTrace;
          capturedContext = context;
        },
      );

      final details = FlutterErrorDetails(
        exception: Exception('flutter error'),
        stack: StackTrace.current,
      );

      reporter.reportFlutterError(details);

      expect(capturedError, details.exception);
      expect(capturedStack, details.stack);
      expect(capturedContext, 'flutter_error');
    });

    test('uses StackTrace.empty when details.stack is null', () {
      StackTrace? capturedStack;

      reporter.init(
        enabled: true,
        remoteReporter: (error, stackTrace, {context}) {
          capturedStack = stackTrace;
        },
      );

      final details = FlutterErrorDetails(
        exception: Exception('no stack'),
        stack: null,
      );

      reporter.reportFlutterError(details);

      expect(capturedStack, StackTrace.empty);
    });

    test('does not invoke callback when disabled', () {
      bool callbackInvoked = false;

      reporter.init(
        enabled: false,
        remoteReporter: (error, stackTrace, {context}) {
          callbackInvoked = true;
        },
      );

      final details = FlutterErrorDetails(
        exception: Exception('test'),
      );

      reporter.reportFlutterError(details);

      expect(callbackInvoked, isFalse);
    });
  });

  group('ErrorReporterCallback typedef', () {
    test('callback signature accepts optional named context', () {
      // Verify the typedef signature compiles and works correctly
      void callback(Object error, StackTrace stackTrace, {String? context}) {}

      // Should not throw
      callback(Exception('test'), StackTrace.empty);
      callback(Exception('test'), StackTrace.empty, context: 'ctx');
    });
  });
}
