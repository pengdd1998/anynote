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
      localizationsDelegates: [
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

    testWidgets('renders toolbar above editor', (tester) async {
      await pumpEditor(tester);

      // Should have a QuillSimpleToolbar.
      expect(find.byType(quill.QuillSimpleToolbar), findsOneWidget);

      // Should have a QuillEditor.
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });

    testWidgets('renders Divider between toolbar and editor', (tester) async {
      await pumpEditor(tester);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('uses Expanded for editor area', (tester) async {
      await pumpEditor(tester);
      expect(find.byType(Expanded), findsOneWidget);
    });

    // =========================================================================
    // Toolbar configuration
    // =========================================================================

    testWidgets('toolbar uses multi-row display', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.multiRowsDisplay, isTrue);
    });

    testWidgets('toolbar hides font family and font size buttons',
        (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showFontFamily, isFalse);
      expect(toolbar.config.showFontSize, isFalse);
    });

    testWidgets('toolbar shows essential formatting buttons', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showBoldButton, isTrue);
      expect(toolbar.config.showItalicButton, isTrue);
      expect(toolbar.config.showUnderLineButton, isTrue);
      expect(toolbar.config.showStrikeThrough, isTrue);
      expect(toolbar.config.showInlineCode, isTrue);
      expect(toolbar.config.showHeaderStyle, isTrue);
    });

    testWidgets('toolbar shows list buttons', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showListNumbers, isTrue);
      expect(toolbar.config.showListBullets, isTrue);
      expect(toolbar.config.showListCheck, isTrue);
    });

    testWidgets('toolbar shows block format buttons', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showCodeBlock, isTrue);
      expect(toolbar.config.showQuote, isTrue);
    });

    testWidgets('toolbar shows undo/redo', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showUndo, isTrue);
      expect(toolbar.config.showRedo, isTrue);
    });

    testWidgets('toolbar hides alignment and color buttons', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showAlignmentButtons, isFalse);
      expect(toolbar.config.showColorButton, isFalse);
      expect(toolbar.config.showBackgroundColorButton, isFalse);
    });

    testWidgets('toolbar hides subscript and superscript', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showSubscript, isFalse);
      expect(toolbar.config.showSuperscript, isFalse);
    });

    testWidgets('toolbar shows link button', (tester) async {
      await pumpEditor(tester);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(toolbar.config.showLink, isTrue);
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

    testWidgets('uses provided QuillController', (tester) async {
      final controller = quill.QuillController.basic();
      await pumpEditor(tester, controller: controller);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(identical(toolbar.controller, controller), isTrue);
    });

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
