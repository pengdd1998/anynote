import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/quick_capture_screen.dart';
import '../../../helpers/test_app_helper.dart';

/// Helper that wraps the [screen] in a [Material] widget so that material
/// components (TextField, IconButton, Chip, etc.) have the required ancestor.
Widget _wrapInMaterial(Widget screen) => Material(child: screen);

void main() {
  group('QuickCaptureScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The screen no longer uses a Scaffold; verify the widget itself renders.
      expect(find.byType(QuickCaptureScreen), findsOneWidget);
      // Verify the TextField is present (core UI element).
      expect(find.byType(TextField), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Quick Capture title in app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Quick Capture'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows text input field with hint', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The TextField should be present with the hint text.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type something...'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows save button in header row', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The header row has an IconButton with check_circle_outline icon.
      expect(
          find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows save and close button in toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Save and close'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows tag picker button in toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byIcon(Icons.label_outline), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows priority selector button in toolbar', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
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
        _wrapInMaterial(const QuickCaptureScreen()),
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
        _wrapInMaterial(const QuickCaptureScreen()),
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
        _wrapInMaterial(const QuickCaptureScreen()),
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
      expect(find.byIcon(Icons.keyboard_double_arrow_up), findsWidgets);

      // A chip with "High" text should appear in the metadata area.
      expect(find.text('High'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows save icon button in header', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen()),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The check_circle_outline icon is the save button in the header.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('pre-fills content from sharedText parameter', (tester) async {
      final handle = await pumpScreen(
        tester,
        _wrapInMaterial(const QuickCaptureScreen(sharedText: 'Shared text content')),
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
        _wrapInMaterial(const QuickCaptureScreen(template: 'checklist')),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The checklist template should be pre-filled.
      expect(find.textContaining('- [ ]'), findsWidgets);

      await handle.dispose();
    });
  });
}
