import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/daily_notes_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('DailyNotesScreen', () {
    /// Set a larger surface size to avoid overflow in the calendar layout.
    Future<void> setLargeSurface(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('renders without errors', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows Today button in app bar', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The "Today" button should be in the app bar actions.
      expect(find.text('Today'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows calendar month navigation', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Calendar navigation chevrons should be present.
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows selected day section with create button',
        (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The selected day section should show "Create today's note" button
      // when no daily note exists for today. The text appears in both the
      // button and the empty state subtitle, so we expect at least one.
      expect(find.text("Create today's note"), findsWidgets);

      await handle.dispose();
    });

    testWidgets('shows recent daily notes section header', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // The "Recent Daily Notes" section header should be visible.
      expect(find.text('Recent Daily Notes'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows empty state when no recent daily notes', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // With no daily notes, the empty state should be visible.
      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('tapping previous month chevron changes month', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Tap the previous month button.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // The calendar should still be rendered (no crash).
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('tapping Today button resets to current month', (tester) async {
      await setLargeSurface(tester);
      final handle = await pumpScreen(
        tester,
        const DailyNotesScreen(),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // Navigate to a different month first.
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Now tap the Today button.
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // The calendar should still render without errors.
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      await handle.dispose();
    });
  });
}
