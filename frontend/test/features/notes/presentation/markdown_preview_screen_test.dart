import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/markdown_preview_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('MarkdownPreviewScreen', () {
    testWidgets('renders without errors', (tester) async {
      final handle = await pumpScreen(
        tester,
        const MarkdownPreviewScreen(noteId: 'test-note-id'),
        overrides: defaultProviderOverrides(),
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
