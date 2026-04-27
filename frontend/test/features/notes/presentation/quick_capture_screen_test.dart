import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/quick_capture_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('QuickCaptureScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Quick Capture title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Quick Capture'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows text input field with hint', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The TextField should be present with the hint text.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type something...'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows close button in app bar leading', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The keyboard_arrow_down icon is the close/dismiss button.
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows save and close button in toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Save and close'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows tag picker button in toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byIcon(Icons.label_outline), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows priority selector button in toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Default state shows flag_outlined icon for priority.
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('can enter text in the content field', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Find the text field and enter some text.
      await tester.enterText(find.byType(TextField), 'Hello quick note');
      await tester.pump();

      expect(find.text('Hello quick note'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('tapping priority button opens bottom sheet', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Tap the priority flag button.
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      // The bottom sheet should show priority options.
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('selecting a priority updates the toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Open priority selector.
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      // Select High priority.
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      // The toolbar should now show the High priority icon (arrow up, red).
      // It appears in both the toolbar icon button and the chip avatar.
      expect(find.byIcon(Icons.keyboard_double_arrow_up), findsWidgets);

      // A chip with "High" text should appear in the metadata area.
      expect(find.text('High'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows save icon buttons', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The check icon (save) should appear in both the app bar and the
      // bottom toolbar's "Save and close" button.
      expect(find.byIcon(Icons.check), findsWidgets);

      await handle.dispose();
    });

    testWidgets('pre-fills content from sharedText parameter', (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(sharedText: 'Shared text content'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The text field should contain the shared text.
      expect(find.text('Shared text content'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('pre-fills checklist template when template is checklist',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const QuickCaptureScreen(template: 'checklist'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The checklist template should be pre-filled.
      expect(find.textContaining('- [ ]'), findsOneWidget);

      await handle.dispose();
    });
  });
}
