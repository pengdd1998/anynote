import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/presentation/widgets/quill_read_only_viewer.dart';

/// The reading view shows a note's text. The empty lines a writer leaves
/// under it stay in the note and out of the reader: a sheet that is half a
/// screen taller than its text looks as if content is missing.
void main() {
  /// Opens [json] and returns the document it shows and the viewer's height.
  Future<(quill.Document, double)> open(
    WidgetTester tester,
    String json,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuillReadOnlyViewer(deltaJson: json, key: ValueKey(json)),
        ),
      ),
    );
    await tester.pump();
    final editor =
        tester.widget<quill.QuillEditor>(find.byType(quill.QuillEditor));
    return (
      editor.controller.document,
      tester.getSize(find.byType(quill.QuillEditor)).height,
    );
  }

  testWidgets('empty lines after the last of the text are not shown', (
    tester,
  ) async {
    const text = '{"insert":"First line.\\nSecond line.\\n"}';
    final (hugging, height) = await open(tester, '[$text]');
    final (padded, paddedHeight) =
        await open(tester, '[$text,{"insert":"\\n\\n\\n\\n\\n"}]');

    expect(hugging.toPlainText(), 'First line.\nSecond line.\n');
    expect(padded.toPlainText(), hugging.toPlainText());
    expect(paddedHeight, closeTo(height, 0.5));
  });

  testWidgets('empty lines inside the text stay', (tester) async {
    final (document, _) = await open(
      tester,
      '[{"insert":"Above.\\n\\n\\nBelow.\\n\\n\\n"}]',
    );

    // Paragraph spacing is the note's; only what follows the text goes.
    expect(document.toPlainText(), 'Above.\n\n\nBelow.\n');
  });

  testWidgets('a note of nothing but empty lines shows one empty line', (
    tester,
  ) async {
    final (document, _) = await open(tester, '[{"insert":"\\n\\n\\n\\n"}]');

    expect(document.toPlainText(), '\n');
  });
}
