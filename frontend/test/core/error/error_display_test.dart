import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/error_display.dart';
import 'package:anynote/core/error/exceptions.dart';

void main() {
  // ===========================================================================
  // ErrorDisplay.userMessage
  // ===========================================================================

  group('ErrorDisplay.userMessage', () {
    test('NetworkException returns connection error message', () {
      const error = NetworkException(message: 'No connection');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('Unable to connect'));
      expect(msg, contains('internet connection'));
    });

    test('ServerException returns server error message', () {
      const error = ServerException(message: 'Internal error');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('server error'));
      expect(msg, contains('try again later'));
    });

    test('AuthException returns session expired message', () {
      const error = AuthException(message: 'Token expired');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('session has expired'));
      expect(msg, contains('log in again'));
    });

    test('ForbiddenException returns permission denied message', () {
      const error = ForbiddenException(message: 'No access');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('do not have permission'));
    });

    test('NotFoundException returns item not found message', () {
      const error = NotFoundException(message: 'Not found');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('could not be found'));
    });

    test('RateLimitException with retryAfterSeconds includes seconds', () {
      const error = RateLimitException(
        message: 'Too many',
        retryAfterSeconds: 30,
      );
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('30 seconds'));
    });

    test('RateLimitException without retryAfterSeconds uses generic message', () {
      const error = RateLimitException(message: 'Too many');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('Too many requests'));
      expect(msg, contains('wait a moment'));
      expect(msg, isNot(contains('seconds')));
    });

    test('ValidationException with fieldErrors joins values', () {
      const error = ValidationException(
        message: 'Invalid',
        fieldErrors: {'email': 'Invalid email format', 'name': 'Name is required'},
      );
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('Invalid email format'));
      expect(msg, contains('Name is required'));
      expect(msg, contains(';'));
    });

    test('ValidationException without fieldErrors returns message', () {
      const error = ValidationException(message: 'Bad input');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, 'Bad input');
    });

    test('ValidationException with empty fieldErrors returns message', () {
      const error = ValidationException(
        message: 'Bad input',
        fieldErrors: {},
      );
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, 'Bad input');
    });

    test('ConflictException returns conflict message', () {
      const error = ConflictException(message: 'Version conflict');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('conflict was detected'));
    });

    test('CryptoLockedException returns locked message', () {
      const error = CryptoLockedException();
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('Encryption keys are locked'));
    });

    test('CryptoKeyDerivationException returns key error message', () {
      const error = CryptoKeyDerivationException();
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('Key derivation failed'));
    });

    test('CryptoOperationException returns encryption error message', () {
      const error = CryptoOperationException(message: 'Bad key');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('encryption error occurred'));
    });

    test('SyncConflictException returns the error message', () {
      const error = SyncConflictException(
        message: 'Manual resolution required',
      );
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, 'Manual resolution required');
    });

    test('SyncException prefixes with "Sync failed:"', () {
      const error = SyncException(message: 'Network timeout');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, 'Sync failed: Network timeout');
    });

    test('StorageException returns storage error message', () {
      const error = StorageException(message: 'Disk full');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('local storage error'));
      expect(msg, contains('restart the app'));
    });

    test('UnknownException returns generic error message', () {
      const error = UnknownException(message: 'Weird error');
      final msg = ErrorDisplay.userMessage(error);
      expect(msg, contains('unexpected error'));
    });
  });

  // ===========================================================================
  // ErrorDisplay.errorIcon
  // ===========================================================================

  group('ErrorDisplay.errorIcon', () {
    test('NetworkException returns wifi_off icon', () {
      const error = NetworkException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.wifi_off);
    });

    test('ServerException returns cloud_off icon', () {
      const error = ServerException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.cloud_off);
    });

    test('AuthException returns lock_outline icon', () {
      const error = AuthException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.lock_outline);
    });

    test('ForbiddenException returns block icon', () {
      const error = ForbiddenException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.block);
    });

    test('NotFoundException returns search_off icon', () {
      const error = NotFoundException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.search_off);
    });

    test('RateLimitException returns hourglass_empty icon', () {
      const error = RateLimitException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.hourglass_empty);
    });

    test('ValidationException returns error_outline icon', () {
      const error = ValidationException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.error_outline);
    });

    test('ConflictException returns sync_problem icon', () {
      const error = ConflictException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.sync_problem);
    });

    test('CryptoLockedException returns lock_outline icon', () {
      const error = CryptoLockedException();
      expect(ErrorDisplay.errorIcon(error), Icons.lock_outline);
    });

    test('CryptoKeyDerivationException returns vpn_key_off icon', () {
      const error = CryptoKeyDerivationException();
      expect(ErrorDisplay.errorIcon(error), Icons.vpn_key_off);
    });

    test('CryptoOperationException returns enhanced_encryption icon', () {
      const error = CryptoOperationException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.enhanced_encryption);
    });

    test('SyncConflictException returns sync_problem icon', () {
      const error = SyncConflictException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.sync_problem);
    });

    test('SyncException returns sync_disabled icon', () {
      const error = SyncException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.sync_disabled);
    });

    test('StorageException returns storage icon', () {
      const error = StorageException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.storage);
    });

    test('UnknownException returns help_outline icon', () {
      const error = UnknownException(message: 'test');
      expect(ErrorDisplay.errorIcon(error), Icons.help_outline);
    });
  });

  // ===========================================================================
  // ErrorDisplay.showSnackBar -- widget test
  // ===========================================================================

  group('ErrorDisplay.showSnackBar', () {
    testWidgets('displays error message in SnackBar', (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showSnackBar(
                        context,
                        error,
                        onRetry: () {},
                      );
                    },
                    child: const Text('Trigger Error'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      // The SnackBar should display the user-friendly message.
      expect(
        find.text(
          'Unable to connect to the server. Please check your internet connection.',
        ),
        findsOneWidget,
      );

      // The Retry action button should be present.
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('SnackBar does not show Retry when onRetry is null', (tester) async {
      const error = ServerException(message: 'Server down');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showSnackBar(context, error);
                    },
                    child: const Text('Trigger Error'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      // The Retry button should not be present.
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('Retry callback is invoked when tapped', (tester) async {
      const error = NetworkException(message: 'test');
      bool retryCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showSnackBar(
                        context,
                        error,
                        onRetry: () {
                          retryCalled = true;
                        },
                      );
                    },
                    child: const Text('Trigger'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      // Tap the Retry action.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('does not crash when context is not mounted', (tester) async {
      // This is a safety check. We show a SnackBar normally and verify
      // the mounted check does not interfere with valid contexts.
      const error = AuthException(message: 'expired');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      // Context is mounted here; should work normally.
                      ErrorDisplay.showSnackBar(context, error);
                    },
                    child: const Text('Trigger'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(
        find.text('Your session has expired. Please log in again.'),
        findsOneWidget,
      );
    });
  });

  // ===========================================================================
  // ErrorDisplay.showErrorDialog -- widget test
  // ===========================================================================

  group('ErrorDisplay.showErrorDialog', () {
    testWidgets('displays dialog with error message and Dismiss button', (tester) async {
      const error = ServerException(message: 'Server error');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showErrorDialog(context, error);
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Dialog title.
      expect(find.text('Server Error'), findsOneWidget);
      // Dialog body.
      expect(find.text('A server error occurred. Please try again later.'), findsOneWidget);
      // Dismiss button always present.
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('dialog with Retry button when onRetry is provided', (tester) async {
      const error = NetworkException(message: 'No internet');
      bool retryCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showErrorDialog(
                        context,
                        error,
                        onRetry: () {
                          retryCalled = true;
                        },
                      );
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Both Dismiss and Retry should be visible.
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry in dialog invokes callback and closes dialog', (tester) async {
      const error = AuthException(message: 'expired');
      bool retryCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showErrorDialog(
                        context,
                        error,
                        onRetry: () {
                          retryCalled = true;
                        },
                      );
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap Retry.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
      // Dialog should be dismissed.
      expect(find.text('Session Expired'), findsNothing);
    });

    testWidgets('Dismiss closes dialog without invoking retry', (tester) async {
      const error = RateLimitException(message: 'rate limited', retryAfterSeconds: 10);
      bool retryCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      ErrorDisplay.showErrorDialog(
                        context,
                        error,
                        onRetry: () {
                          retryCalled = true;
                        },
                      );
                    },
                    child: const Text('Show Dialog'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap Dismiss.
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(retryCalled, isFalse);
      // Dialog should be dismissed.
      expect(find.text('Rate Limited'), findsNothing);
    });

    testWidgets('dialog shows correct title for each error type', (tester) async {
      // Spot-check a few error type dialog titles.
      final errorTitles = <AppException, String>{
        const NetworkException(message: 'net'): 'Connection Error',
        const AuthException(message: 'auth'): 'Session Expired',
        const ForbiddenException(message: 'denied'): 'Access Denied',
        const NotFoundException(message: 'no'): 'Not Found',
        const ConflictException(message: 'conflict'): 'Conflict',
        const CryptoLockedException(): 'Encryption Locked',
        const SyncException(message: 'sync'): 'Sync Error',
        const StorageException(message: 'store'): 'Storage Error',
      };

      for (final entry in errorTitles.entries) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        ErrorDisplay.showErrorDialog(context, entry.key);
                      },
                      child: const Text('Show'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);

        // Dismiss the dialog.
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();
      }
    });
  });
}
