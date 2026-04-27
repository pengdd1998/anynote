import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/error_state_widget.dart';

void main() {
  // Helper to pump ErrorStateWidget inside a minimal MaterialApp.
  Future<void> pumpErrorWidget(
    WidgetTester tester, {
    required String message,
    VoidCallback? onRetry,
    IconData icon = Icons.error_outline,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorStateWidget(
            message: message,
            onRetry: onRetry,
            icon: icon,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Basic rendering
  // ===========================================================================

  group('ErrorStateWidget basic rendering', () {
    testWidgets('renders the error message text', (tester) async {
      await pumpErrorWidget(tester, message: 'Something went wrong');

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders the default error icon', (tester) async {
      await pumpErrorWidget(tester, message: 'Error');

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders a custom icon when provided', (tester) async {
      await pumpErrorWidget(
        tester,
        message: 'Network error',
        icon: Icons.cloud_off,
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('renders icon at size 48', (tester) async {
      await pumpErrorWidget(tester, message: 'Error');

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      expect(icon.size, 48);
    });

    testWidgets('icon uses error color from theme', (tester) async {
      await pumpErrorWidget(tester, message: 'Error');

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      final theme = ThemeData(useMaterial3: true);
      expect(icon.color, theme.colorScheme.error);
    });

    testWidgets('renders inside a Center widget', (tester) async {
      await pumpErrorWidget(tester, message: 'Error');

      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('message text is center-aligned', (tester) async {
      await pumpErrorWidget(tester, message: 'Centered error');

      final textWidget = tester.widget<Text>(find.text('Centered error'));
      expect(textWidget.textAlign, TextAlign.center);
    });
  });

  // ===========================================================================
  // Retry button
  // ===========================================================================

  group('ErrorStateWidget retry button', () {
    testWidgets('renders retry button when onRetry is provided',
        (tester) async {
      await pumpErrorWidget(
        tester,
        message: 'Error',
        onRetry: () {},
      );

      // The button should show either the localized "Retry" or the fallback.
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('retry button callback is invoked on tap', (tester) async {
      var retryPressed = false;
      await pumpErrorWidget(
        tester,
        message: 'Tap retry',
        onRetry: () => retryPressed = true,
      );

      // Find the FilledButton and tap it.
      await tester.tap(find.byType(FilledButton));
      expect(retryPressed, isTrue);
    });

    testWidgets('does not render retry button when onRetry is null',
        (tester) async {
      await pumpErrorWidget(
        tester,
        message: 'No retry',
        // onRetry intentionally omitted
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('retry button text fallback is "Retry" when no localization',
        (tester) async {
      // Without localization delegates, AppLocalizations.of(context) is null,
      // so the fallback 'Retry' should be shown.
      await pumpErrorWidget(
        tester,
        message: 'Error',
        onRetry: () {},
      );

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Different configurations
  // ===========================================================================

  group('ErrorStateWidget configurations', () {
    testWidgets('renders with cloud-off icon and long message', (tester) async {
      const longMessage =
          'A very long error message that describes something that went wrong '
          'during a network operation. It should still render correctly and '
          'wrap to multiple lines.';
      await pumpErrorWidget(
        tester,
        message: longMessage,
        icon: Icons.cloud_off,
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text(longMessage), findsOneWidget);
    });

    testWidgets('renders with warning icon', (tester) async {
      await pumpErrorWidget(
        tester,
        message: 'Warning occurred',
        icon: Icons.warning_amber,
      );

      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    });

    testWidgets('renders with connection-lost scenario', (tester) async {
      await pumpErrorWidget(
        tester,
        message: 'Connection lost',
        icon: Icons.signal_wifi_off,
        onRetry: () {},
      );

      expect(find.byIcon(Icons.signal_wifi_off), findsOneWidget);
      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('padding is applied around the content', (tester) async {
      await pumpErrorWidget(tester, message: 'Error');

      // Verify there is a Padding widget with the expected value.
      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.byIcon(Icons.error_outline),
          matching: find.byType(Padding),
        ),
      );

      final edgeInsets = padding.padding as EdgeInsets;
      expect(edgeInsets.bottom, 24);
    });
  });
}
