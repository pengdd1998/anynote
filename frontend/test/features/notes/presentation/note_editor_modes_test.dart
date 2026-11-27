import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/note_editor_screen.dart';

import '../../../helpers/design_gallery.dart';
import '../../../helpers/test_app_helper.dart';

/// The editor has two editors over one note — rich text and plain text —
/// and a switch between them. Seen on the phone on 2026-11-27: the plain one
/// showed a rich note's raw JSON, a switch carried nothing from one to the
/// other, and opening a note saved it.
void main() {
  /// Two lines, the second one bold.
  const delta = '[{"insert":"Line one."},{"insert":"\\n"},'
      '{"insert":"Line two.","attributes":{"bold":true}},{"insert":"\\n"}]';

  /// Another rich note: one line, italic.
  const otherDelta =
      '[{"insert":"Other line.","attributes":{"italic":true}},{"insert":"\\n"}]';

  /// Stores [notes] (id → content) and opens the first of them. The caller
  /// closes with [close].
  Future<(ProviderContainer, AppDatabase)> open(
    WidgetTester tester,
    Map<String, String> notes,
  ) async {
    // Screens read preferences as soon as they build.
    SharedPreferences.setMockInitialValues({});
    final database = createTestDatabase();
    for (final entry in notes.entries) {
      await database.notesDao.createNote(
        id: entry.key,
        encryptedContent: 'enc_${entry.value}',
        plainContent: entry.value,
        plainTitle: 'Line one.',
        encryptedTitle: 'enc_Line one.',
      );
    }
    final container = ProviderContainer(
      overrides: defaultProviderOverrides(db: database),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: galleryApp(
          NoteEditorScreen(noteId: notes.keys.first),
          locale: const Locale('en'),
        ),
      ),
    );
    await settle(tester);
    return (container, database);
  }

  /// The same screen, moved to another note — the way a list beside the
  /// editor opens the next one.
  Future<void> show(
    WidgetTester tester,
    ProviderContainer container,
    String noteId,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: galleryApp(
          NoteEditorScreen(noteId: noteId),
          locale: const Locale('en'),
        ),
      ),
    );
    await settle(tester);
  }

  /// Takes everything down inside the test: the editor leaves timers behind.
  Future<void> close(
    WidgetTester tester,
    (ProviderContainer, AppDatabase) opened,
  ) async {
    final (container, database) = opened;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(
      () => database.close().timeout(
            const Duration(seconds: 2),
            onTimeout: () {},
          ),
    );
  }

  /// The text of whichever editor is on screen.
  String textOnScreen(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  /// The rich document, whether or not its editor is on screen.
  quill.Document richDocument(WidgetTester tester) => tester
      .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
      .controller
      .document;

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> toPlain(WidgetTester tester) =>
      tapAndSettle(tester, find.byTooltip('Plain text'));

  Future<void> toRich(WidgetTester tester) =>
      tapAndSettle(tester, find.byTooltip('Rich text'));

  testWidgets('a rich note opened in plain text shows its words, not its JSON',
      (
    tester,
  ) async {
    final opened = await open(tester, {'n1': delta});
    try {
      await toPlain(tester);

      expect(textOnScreen(tester), 'Line one.\nLine two.');
      expect(textOnScreen(tester), isNot(contains('insert')));

      // And back with nothing changed: the document as it was, bold and all.
      await toRich(tester);
      final json = jsonEncode(richDocument(tester).toDelta().toJson());
      expect(richDocument(tester).toPlainText(), 'Line one.\nLine two.\n');
      expect(json, contains('"bold":true'));
    } finally {
      await close(tester, opened);
    }
  });

  testWidgets(
      'a sentence written in plain text is in the rich document after a switch',
      (
    tester,
  ) async {
    // It was not: the rich document kept what it had when the note was
    // loaded, and the next save dropped the sentence.
    final opened = await open(tester, {'n1': delta});
    try {
      await toPlain(tester);
      await tester.enterText(
        find.byType(EditableText),
        'Line one.\nLine two.\nAdded in plain text.',
      );
      await toRich(tester);

      expect(
        richDocument(tester).toPlainText(),
        'Line one.\nLine two.\nAdded in plain text.\n',
      );
    } finally {
      await close(tester, opened);
    }
  });

  testWidgets(
      'what the rich document gained is in the plain text after a switch', (
    tester,
  ) async {
    final opened = await open(tester, {'n1': delta});
    try {
      final controller = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      controller.document.insert(controller.document.length - 1, ' Added.');
      await tester.pump();

      await toPlain(tester);

      expect(textOnScreen(tester), 'Line one.\nLine two. Added.');
    } finally {
      await close(tester, opened);
    }
  });

  testWidgets('switching back and forth with no edit does not grow the note', (
    tester,
  ) async {
    // A document ends in a line break that is not the note's. Left on the
    // plain text, every round of switching added an empty line.
    final opened =
        await open(tester, {'n1': 'First paragraph.\n\nSecond paragraph.'});
    try {
      await toPlain(tester);
      await toRich(tester);
      await toPlain(tester);

      expect(textOnScreen(tester), 'First paragraph.\n\nSecond paragraph.');
    } finally {
      await close(tester, opened);
    }
  });

  testWidgets(
    'a note opened while the editor is in plain text shows its words, and comes back whole',
    (tester) async {
      // The editor keeps its mode between notes. Opened in plain text, a
      // rich note showed its raw JSON.
      final opened = await open(tester, {'n1': delta, 'n2': otherDelta});
      try {
        await toPlain(tester);
        await show(tester, opened.$1, 'n2');

        expect(textOnScreen(tester), 'Other line.');
        expect(textOnScreen(tester), isNot(contains('insert')));

        // Nothing changed in plain text: the document comes back as it was.
        await toRich(tester);
        final json = jsonEncode(richDocument(tester).toDelta().toJson());
        expect(richDocument(tester).toPlainText(), 'Other line.\n');
        expect(json, contains('"italic":true'));
      } finally {
        await close(tester, opened);
      }
    },
  );

  testWidgets('opening a note does not save it', (tester) async {
    // Loading set text on a controller, which was taken for an edit: a new
    // version snapshot twice over, a bumped time and a sync, on every open.
    final opened = await open(tester, {'n1': delta});
    try {
      final before = await tester.runAsync(
        () => opened.$2.notesDao.getNoteById('n1'),
      );
      // Well past the autosave delay.
      await tester.pump(const Duration(seconds: 5));
      final note = await tester.runAsync(
        () => opened.$2.notesDao.getNoteById('n1'),
      );
      final versions = await tester.runAsync(
        () => opened.$2.noteVersionsDao.getVersionCount('n1'),
      );

      expect(note?.plainContent, delta);
      expect(note?.updatedAt, before?.updatedAt);
      expect(versions, 0);
    } finally {
      await close(tester, opened);
    }
  });
}
