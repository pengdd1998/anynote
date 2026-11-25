import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/note_rich_preview.dart';
import 'package:anynote/main.dart';

/// A preview has four lines to spend. Notes are written with a blank line
/// between paragraphs, and while a blank line counted as a line, four lines
/// showed two of text.
void main() {
  const body = 'Title\n\nFirst\n\nSecond\n\nThird\n\nFourth\n\nFifth';

  AppDatabase? db;

  setUpAll(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await db?.close();
  });

  tearDown(() async {
    // Let what the content load queued run out.
    await Future.delayed(const Duration(milliseconds: 200));
  });

  Future<RenderParagraph> pump(WidgetTester tester, String content) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db!)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: NoteRichPreview(
                // Content that is not a Delta is read as plain text.
                note: _note(content),
                maxLines: 4,
                skipFirstLine: true,
              ),
            ),
          ),
        ),
      ),
    );
    // The content is read in initState's first async step.
    await tester.pump();
    await tester.pump();
    return tester.renderObject<RenderParagraph>(find.byType(RichText));
  }

  /// Where the line holding [word] starts.
  double topOf(RenderParagraph paragraph, String word) => paragraph
      .getOffsetForCaret(
        TextPosition(offset: paragraph.text.toPlainText().indexOf(word)),
        Rect.zero,
      )
      .dy;

  /// The paragraphs sit on consecutive lines — no blank one between them —
  /// and the fourth line of the preview is the fourth line of text.
  void expectParagraphsConsecutive(RenderParagraph paragraph) {
    final first = topOf(paragraph, 'First');
    final second = topOf(paragraph, 'Second');
    final third = topOf(paragraph, 'Third');
    final fourth = topOf(paragraph, 'Fourth');
    expect(third - second, closeTo(second - first, 0.5));
    expect(fourth - third, closeTo(second - first, 0.5));
    expect(paragraph.size.height, closeTo(4 * (second - first), 1));
  }

  // The paragraph's text, each line followed by the newline the span
  // builder puts after it.
  const laidOut = 'First\nSecond\nThird\nFourth\nFifth\n';

  testWidgets('plain text: four lines of text, no blank ones', (tester) async {
    final paragraph = await pump(tester, body);

    expect(paragraph.text.toPlainText(), laidOut.trimRight());
    expectParagraphsConsecutive(paragraph);
  });

  testWidgets('rich text: four lines of text, no blank ones', (tester) async {
    // The same note as a Delta, which is how the editor stores it.
    final paragraph = await pump(tester, '[{"insert": ${_jsonString(body)}}]');

    expect(paragraph.text.toPlainText(), laidOut);
    expectParagraphsConsecutive(paragraph);
  });

  testWidgets('a list keeps its items together', (tester) async {
    // Blank lines around a list are paragraph spacing; the bullets are
    // content, and each keeps its own line.
    const delta = '[{"insert":"Title\\n\\n"},'
        '{"insert":"Milk\\n","attributes":{"list":"bullet"}},'
        '{"insert":"Bread\\n","attributes":{"list":"bullet"}},'
        '{"insert":"\\n"},'
        '{"insert":"Done"}]';
    final paragraph = await pump(tester, delta);

    expect(paragraph.text.toPlainText(), '•  Milk\n•  Bread\nDone\n');
  });
}

Note _note(String plainContent) => Note(
      id: 'note-1',
      encryptedContent: 'enc',
      encryptedTitle: 'enc',
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      isSynced: false,
      isPinned: false,
      plainContent: plainContent,
      sortOrder: 0,
    );

/// [text] as a JSON string literal.
String _jsonString(String text) =>
    '"${text.replaceAll(r'\', r'\\').replaceAll('\n', r'\n')}"';
