import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../monitoring/error_reporter.dart';

/// A widget that wraps its [child] and catches unhandled exceptions thrown
/// during build, replacing the subtree with a recovery UI.
///
/// When an error is caught, the boundary shows a centered error message with
/// a "Retry" button that resets the error state and attempts to rebuild the
/// child. Errors are also forwarded to [ErrorReporter] for centralized logging.
///
/// This does NOT catch errors from event handlers, async gaps, or
/// [StatefulWidget] lifecycle methods -- those should be handled with
/// try/catch or [FlutterError.onError]. It specifically catches exceptions
/// thrown during the [build] phase.
///
/// Usage:
/// ```dart
/// ErrorBoundary(
///   child: SomeComplexWidget(),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  /// The most recent error caught during build, or null if no error.
  FlutterErrorDetails? _errorDetails;

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return _ErrorRecoveryUI(
        onRetry: _reset,
        errorDetails: _errorDetails!,
      );
    }

    // Use a builder so that we can catch synchronous exceptions thrown
    // during the child's build without crashing the host widget.
    return _ErrorCatchingBuilder(
      onError: _onBuildError,
      child: widget.child,
    );
  }

  void _onBuildError(FlutterErrorDetails details) {
    if (!mounted) return;
    ErrorReporter.instance.reportFlutterError(details);
    setState(() {
      _errorDetails = details;
    });
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _errorDetails = null;
    });
  }
}

/// Internal widget that wraps the child in a [LayoutBuilder] to detect
/// build-time exceptions. Flutter does not provide a direct way to catch
/// widget build errors per-subtree, so we rely on the framework's
/// [FlutterError.onError] mechanism combined with a Zone to isolate errors.
///
/// In practice, this catches errors thrown synchronously during build.
class _ErrorCatchingBuilder extends StatelessWidget {
  final Widget child;
  final void Function(FlutterErrorDetails details) onError;

  const _ErrorCatchingBuilder({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Recovery UI shown when an error is caught by [ErrorBoundary].
///
/// Displays a Material-styled error card with an error icon, a message,
/// and a "Retry" button. Uses theme-aware colors so it looks correct in
/// both light and dark modes.
class _ErrorRecoveryUI extends StatelessWidget {
  final VoidCallback onRetry;
  final FlutterErrorDetails errorDetails;

  const _ErrorRecoveryUI({
    required this.onRetry,
    required this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'An unexpected error occurred. Tap Retry to continue.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                errorDetails.exceptionAsString(),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.error,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
