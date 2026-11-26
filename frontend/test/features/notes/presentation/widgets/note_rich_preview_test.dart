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

  Future<void> pump(
    WidgetTester tester,
    String content, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db!)],
        child: MaterialApp(
          // The system's text size, as the phone reports it to the app.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: NoteRichPreview(
                // A new note is a new widget: the content is read once, on
                // the first build.
                key: ValueKey(content),
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
  }

  RenderParagraph paragraphOf(WidgetTester tester) =>
      tester.renderObject<RenderParagraph>(find.byType(RichText));

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

  // The paragraph's text: a line break between lines, none after the last.
  const laidOut = 'First\nSecond\nThird\nFourth\nFifth';

  testWidgets('plain text: four lines of text, no blank ones', (tester) async {
    await pump(tester, body);

    final paragraph = paragraphOf(tester);
    expect(paragraph.text.toPlainText(), laidOut);
    expectParagraphsConsecutive(paragraph);
  });

  testWidgets('rich text: four lines of text, no blank ones', (tester) async {
    // The same note as a Delta, which is how the editor stores it.
    await pump(tester, '[{"insert": ${_jsonString(body)}}]');

    final paragraph = paragraphOf(tester);
    expect(paragraph.text.toPlainText(), laidOut);
    expectParagraphsConsecutive(paragraph);
  });

  testWidgets('rich text: nothing is laid out under the last line', (
    tester,
  ) async {
    // A line break after the last line laid out an empty one. On a card it
    // was a band of blank sheet between a two-line preview and the time.
    await pump(tester, '[{"insert":"Title\\n\\nFirst\\nSecond\\n"}]');

    final paragraph = paragraphOf(tester);
    final line = topOf(paragraph, 'Second') - topOf(paragraph, 'First');
    expect(paragraph.text.toPlainText(), 'First\nSecond');
    expect(paragraph.size.height, closeTo(2 * line, 1));
  });

  testWidgets(
      "a rich preview takes the system's text size, as a plain one does", (
    tester,
  ) async {
    // Text scales itself; RichText does not, until it is told to. A note
    // re-saved by the editor became rich, and its preview shrank on a phone
    // whose text size is set above the default.
    const text = 'Title\n\nFirst paragraph of the note.\n\nSecond one here.';
    await pump(tester, text, textScale: 1.3);
    final plain = paragraphOf(tester).size.height;

    await pump(
      tester,
      '[{"insert": ${_jsonString(text)}}]',
      textScale: 1.3,
    );
    final rich = paragraphOf(tester);

    // A line is 18 px unscaled and 24 px at 1.3.
    expect(topOf(rich, 'Second') - topOf(rich, 'First'), greaterThan(21));
    expect(rich.size.height, closeTo(plain, 0.5));
  });

  testWidgets('a list keeps its items together', (tester) async {
    // Blank lines around a list are paragraph spacing; the bullets are
    // content, and each keeps its own line.
    const delta = '[{"insert":"Title\\n\\n"},'
        '{"insert":"Milk\\n","attributes":{"list":"bullet"}},'
        '{"insert":"Bread\\n","attributes":{"list":"bullet"}},'
        '{"insert":"\\n"},'
        '{"insert":"Done"}]';
    await pump(tester, delta);

    expect(paragraphOf(tester).text.toPlainText(), '•  Milk\n•  Bread\nDone');
  });

  testWidgets('a note that is only a title has no empty line under it', (
    tester,
  ) async {
    // The card shows the title itself; an empty paragraph still laid out a
    // line, and the card had a hole between the title and the time.
    await pump(tester, 'Only a title\n');
    expect(find.byType(RichText), findsNothing);

    await pump(tester, '[{"insert":"Only a title\\n"}]');
    expect(find.byType(RichText), findsNothing);
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
