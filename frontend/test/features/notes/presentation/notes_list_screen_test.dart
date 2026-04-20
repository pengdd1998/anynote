import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/notes_list_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('NotesListScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has app bar', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows floating action button', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NotesListScreen(autoLoad: false),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      // NotesListScreen should have a FAB for creating new notes.
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
