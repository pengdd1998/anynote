import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/note_detail_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('NoteDetailScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const NoteDetailScreen(noteId: 'test-note-id'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
