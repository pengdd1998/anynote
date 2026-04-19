import 'package:flutter/material.dart';

import 'exceptions.dart';

// ignore: unused_import used to disambiguate the static showDialog method
// from Flutter's material showDialog function.

/// Utility class for displaying errors to the user in a consistent manner.
///
/// Use [showSnackBar] for transient, non-critical errors (network failures,
/// sync issues). Use [showDialog] for critical errors that need acknowledgment
/// (auth failures, data corruption).
class ErrorDisplay {
  ErrorDisplay._();

  /// Show an error as a [SnackBar] at the bottom of the screen.
  ///
  /// Optionally provide [onRetry] to show a retry action button.
  static void showSnackBar(
    BuildContext context,
    AppException error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(errorIcon(error), color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userMessage(error),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: _snackBarColor(error),
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show an error as an [AlertDialog] that requires user acknowledgment.
  ///
  /// Optionally provide [onRetry] to add a retry button alongside Dismiss.
  static void showErrorDialog(
    BuildContext context,
    AppException error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(errorIcon(error), size: 32),
        title: Text(_dialogTitle(error)),
        content: Text(userMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          if (onRetry != null)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Get a human-friendly message for the given error.
  ///
  /// This produces consistent, user-facing strings for each error type.
  static String userMessage(AppException error) {
    return switch (error) {
      NetworkException() =>
        'Unable to connect to the server. Please check your internet connection.',
      ServerException() => 'A server error occurred. Please try again later.',
      AuthException() =>
        'Your session has expired. Please log in again.',
      ForbiddenException() =>
        'You do not have permission to perform this action.',
      NotFoundException() =>
        'The requested item could not be found.',
      RateLimitException(:final retryAfterSeconds?) =>
        'Too many requests. Please wait $retryAfterSeconds seconds and try again.',
      RateLimitException() =>
        'Too many requests. Please wait a moment and try again.',
      ValidationException(:final fieldErrors?) when fieldErrors.isNotEmpty =>
        fieldErrors.values.join('; '),
      ValidationException() => error.message,
      ConflictException() =>
        'A conflict was detected. Please refresh and try again.',
      CryptoLockedException() =>
        'Encryption keys are locked. Please unlock to continue.',
      CryptoKeyDerivationException() =>
        'Key derivation failed. Please check your password.',
      CryptoOperationException() =>
        'An encryption error occurred. Please try again.',
      SyncConflictException() => error.message,
      SyncException() => 'Sync failed: ${error.message}',
      StorageException() =>
        'A local storage error occurred. Please restart the app.',
      UnknownException() =>
        'An unexpected error occurred. Please try again.',
      _ => error.message,
    };
  }

  /// Get an appropriate icon for the given error type.
  static IconData errorIcon(AppException error) {
    return switch (error) {
      NetworkException() => Icons.wifi_off,
      ServerException() => Icons.cloud_off,
      AuthException() => Icons.lock_outline,
      ForbiddenException() => Icons.block,
      NotFoundException() => Icons.search_off,
      RateLimitException() => Icons.hourglass_empty,
      ValidationException() => Icons.error_outline,
      ConflictException() => Icons.sync_problem,
      CryptoLockedException() => Icons.lock_outline,
      CryptoKeyDerivationException() => Icons.vpn_key_off,
      CryptoOperationException() => Icons.enhanced_encryption,
      SyncConflictException() => Icons.sync_problem,
      SyncException() => Icons.sync_disabled,
      StorageException() => Icons.storage,
      UnknownException() => Icons.help_outline,
      _ => Icons.error_outline,
    };
  }

  /// Get a short dialog title for the given error type.
  static String _dialogTitle(AppException error) {
    return switch (error) {
      NetworkException() => 'Connection Error',
      ServerException() => 'Server Error',
      AuthException() => 'Session Expired',
      ForbiddenException() => 'Access Denied',
      NotFoundException() => 'Not Found',
      RateLimitException() => 'Rate Limited',
      ValidationException() => 'Invalid Input',
      ConflictException() => 'Conflict',
      CryptoLockedException() => 'Encryption Locked',
      CryptoKeyDerivationException() => 'Key Error',
      CryptoOperationException() => 'Encryption Error',
      SyncConflictException() => 'Sync Conflict',
      SyncException() => 'Sync Error',
      StorageException() => 'Storage Error',
      _ => 'Error',
    };
  }

  /// Determine SnackBar background color based on error severity.
  static Color _snackBarColor(AppException error) {
    return switch (error) {
      NetworkException() => Colors.grey.shade800,
      AuthException() => Colors.orange.shade800,
      RateLimitException() => Colors.orange.shade800,
      CryptoException() => Colors.red.shade800,
      _ => Colors.red.shade700,
    };
  }
}
