import 'package:flutter/material.dart';

/// Unified SnackBar helper ensuring consistent behavior across the app.
///
/// All snack bars use floating behavior and standardized durations:
/// - Info: 3 seconds
/// - Error: 5 seconds
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = type == SnackBarType.error
        ? const Duration(seconds: 5)
        : const Duration(seconds: 3);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: type == SnackBarType.error ? colorScheme.error : null,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Convenience method for error snack bars.
  static void error(BuildContext context, {required String message}) {
    show(context, message: message, type: SnackBarType.error);
  }

  /// Convenience method for info snack bars with optional undo action.
  static void info(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      type: SnackBarType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

enum SnackBarType { info, error }
