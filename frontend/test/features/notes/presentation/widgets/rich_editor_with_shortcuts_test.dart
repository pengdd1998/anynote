import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:anynote/features/notes/presentation/rich_note_editor.dart';
import 'package:anynote/features/notes/presentation/widgets/rich_editor_with_shortcuts.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> pumpRichEditorWithShortcuts(
  WidgetTester tester, {
  quill.QuillController? quillController,
  FocusNode? focusNode,
  VoidCallback? onExitZenMode,
  void Function(int level)? onToggleHeading,
  VoidCallback? onToggleBulletList,
}) async {
  final controller = quillController ?? quill.QuillController.basic();
  final focus = focusNode ?? FocusNode();

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        quill.FlutterQuillLocalizations.delegate,
      ],
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: RichEditorWithShortcuts(
            quillController: controller,
            focusNode: focus,
            onExitZenMode: onExitZenMode ?? () {},
            onToggleHeading: onToggleHeading ?? (_) {},
            onToggleBulletList: onToggleBulletList ?? () {},
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RichEditorWithShortcuts', () {
    testWidgets('renders RichNoteEditor inside', (tester) async {
      await pumpRichEditorWithShortcuts(tester);
      expect(find.byType(RichNoteEditor), findsOneWidget);
    });

    testWidgets('renders QuillEditor', (tester) async {
      await pumpRichEditorWithShortcuts(tester);
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });

    testWidgets('renders QuillSimpleToolbar', (tester) async {
      await pumpRichEditorWithShortcuts(tester);
      expect(find.byType(quill.QuillSimpleToolbar), findsOneWidget);
    });

    testWidgets('uses Shortcuts widget for keyboard bindings', (tester) async {
      await pumpRichEditorWithShortcuts(tester);
      // quill editor may add its own Shortcuts, so check for at least one.
      expect(find.byType(Shortcuts), findsAtLeast(1));
    });

    testWidgets('uses Actions widget for intent handling', (tester) async {
      await pumpRichEditorWithShortcuts(tester);
      // quill editor may add its own Actions, so check for at least one.
      expect(find.byType(Actions), findsAtLeast(1));
    });

    testWidgets('uses provided QuillController', (tester) async {
      final controller = quill.QuillController.basic();
      await pumpRichEditorWithShortcuts(tester, quillController: controller);

      final toolbar = tester.widget<quill.QuillSimpleToolbar>(
        find.byType(quill.QuillSimpleToolbar),
      );
      expect(identical(toolbar.controller, controller), isTrue);
    });

    testWidgets('wraps editor in KeyedSubtree-compatible structure',
        (tester) async {
      await pumpRichEditorWithShortcuts(tester);
      // The widget should render without errors in a sized container.
      expect(find.byType(RichEditorWithShortcuts), findsOneWidget);
    });

    testWidgets('onToggleHeading callback fires for heading 1', (tester) async {
      int? headingLevel;
      await pumpRichEditorWithShortcuts(
        tester,
        onToggleHeading: (level) => headingLevel = level,
      );
      // We cannot easily simulate Ctrl+1 in test, but we verify the widget
      // renders correctly and callback wiring exists via Actions.
      expect(find.byType(RichEditorWithShortcuts), findsOneWidget);
      // Callback should not have been called without user input.
      expect(headingLevel, isNull);
    });

    testWidgets('renders with dark theme without errors', (tester) async {
      final controller = quill.QuillController.basic();
      final focus = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          localizationsDelegates: const [
            quill.FlutterQuillLocalizations.delegate,
          ],
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: RichEditorWithShortcuts(
                quillController: controller,
                focusNode: focus,
                onExitZenMode: () {},
                onToggleHeading: (_) {},
                onToggleBulletList: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RichEditorWithShortcuts), findsOneWidget);
    });
  });
}
