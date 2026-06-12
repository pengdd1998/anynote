import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:anynote/features/notes/presentation/rich_note_editor.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> pumpEditor(
  WidgetTester tester, {
  quill.QuillController? controller,
  FocusNode? focusNode,
  ThemeData? theme,
}) async {
  final ctrl = controller ?? quill.QuillController.basic();
  final focus = focusNode ?? FocusNode();

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.light(),
      localizationsDelegates: const [
        quill.FlutterQuillLocalizations.delegate,
      ],
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: RichNoteEditor(
            controller: ctrl,
            focusNode: focus,
          ),
        ),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // Structure
  // ===========================================================================

  group('RichNoteEditor', () {
    testWidgets('renders Column layout', (tester) async {
      await pumpEditor(tester);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('renders QuillEditor', (tester) async {
      await pumpEditor(tester);

      // Should have a QuillEditor.
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });

    testWidgets('uses Expanded for editor area', (tester) async {
      await pumpEditor(tester);
      expect(find.byType(Expanded), findsOneWidget);
    });

    // =========================================================================
    // Theme adaptation
    // =========================================================================

    testWidgets('renders with dark theme without errors', (tester) async {
      await pumpEditor(tester, theme: ThemeData.dark());
      expect(find.byType(RichNoteEditor), findsOneWidget);
    });

    testWidgets('renders with light theme without errors', (tester) async {
      await pumpEditor(tester, theme: ThemeData.light());
      expect(find.byType(RichNoteEditor), findsOneWidget);
    });

    // =========================================================================
    // Controller integration
    // =========================================================================

    testWidgets('uses provided FocusNode', (tester) async {
      final focusNode = FocusNode();
      try {
        await pumpEditor(tester, focusNode: focusNode);

        // The editor should use the provided FocusNode.
        final editor = tester.widget<quill.QuillEditor>(
          find.byType(quill.QuillEditor),
        );
        expect(editor.focusNode, focusNode);
      } finally {
        focusNode.dispose();
      }
    });
  });
}
