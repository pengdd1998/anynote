import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'exceptions.dart';

/// Utility class for displaying errors to the user in a consistent manner.
///
/// Use [showSnackBar] for transient, non-critical errors (network failures,
/// sync issues). Use [showErrorDialog] for critical errors that need acknowledgment
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
    final l10n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(errorIcon(error), color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userMessage(error, l10n),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: _snackBarColor(error),
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: l10n.retry,
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
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(errorIcon(error), size: 32),
        title: Text(dialogTitle(error, l10n)),
        content: Text(userMessage(error, l10n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dismiss),
          ),
          if (onRetry != null)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: Text(l10n.retry),
            ),
        ],
      ),
    );
  }

  /// Get a human-friendly message for the given error.
  ///
  /// When [l10n] is provided, localized strings are used. Otherwise, English
  /// fallback strings are returned.
  static String userMessage(AppException error, [AppLocalizations? l10n]) {
    if (l10n == null) return _fallbackUserMessage(error);
    return switch (error) {
      NetworkException() => l10n.errorConnection,
      ServerException() => l10n.errorServer,
      AuthException() => l10n.errorSessionExpired,
      ForbiddenException() => l10n.errorAccessDenied,
      NotFoundException() => l10n.errorNotFound,
      RateLimitException(:final retryAfterSeconds?) =>
        l10n.errorRateLimitedSeconds(retryAfterSeconds),
      RateLimitException() => l10n.errorRateLimited,
      ValidationException(:final fieldErrors?) when fieldErrors.isNotEmpty =>
        fieldErrors.values.join('; '),
      ValidationException() => error.message,
      ConflictException() => l10n.errorConflict,
      CryptoLockedException() => l10n.errorCryptoLocked,
      CryptoKeyDerivationException() => l10n.errorKeyDerivation,
      CryptoOperationException() => l10n.errorCryptoOperation,
      SyncConflictException() => error.message,
      SyncException() => l10n.errorSync(error.message),
      StorageException() => l10n.errorStorage,
      UnknownException() => l10n.errorUnexpected,
      _ => error.message,
    };
  }

  /// English fallback messages when l10n is not available.
  static String _fallbackUserMessage(AppException error) {
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
  static String dialogTitle(AppException error, AppLocalizations l10n) {
    return switch (error) {
      NetworkException() => l10n.errorTitleConnection,
      ServerException() => l10n.errorTitleServer,
      AuthException() => l10n.errorTitleSessionExpired,
      ForbiddenException() => l10n.errorTitleAccessDenied,
      NotFoundException() => l10n.errorTitleNotFound,
      RateLimitException() => l10n.errorTitleRateLimited,
      ValidationException() => l10n.errorTitleInvalidInput,
      ConflictException() => l10n.errorTitleConflict,
      CryptoLockedException() => l10n.errorTitleCryptoLocked,
      CryptoKeyDerivationException() => l10n.errorTitleKeyError,
      CryptoOperationException() => l10n.errorTitleCrypto,
      SyncConflictException() => l10n.errorTitleSync,
      SyncException() => l10n.errorTitleSync,
      StorageException() => l10n.errorTitleStorage,
      _ => l10n.errorTitleServer,
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
