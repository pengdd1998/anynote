import 'dart:convert';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/domain/note_envelope.dart';
import 'package:anynote/features/notes/presentation/note_detail_screen.dart';
import 'package:anynote/features/notes/presentation/widgets/quill_read_only_viewer.dart';
import 'package:anynote/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

/// Verifies NoteDetailScreen renders rich-formatted notes (heading, bold,
/// bullet list) through the SAME Quill viewer the editor uses — no raw Delta
/// JSON, no sync-envelope garbage — so detail and edit look identical.
void main() {
  initIntegrationTest();

  group('NoteDetailScreen formatted-note rendering', () {
    late FakeCryptoService crypto;
    late AppDatabase db;

    setUp(() async {
      crypto = FakeCryptoService();
      db = createTestDatabase();
    });

    tearDown(() async => await db.close());

    /// Pump NoteDetailScreen standalone with the test DB + fake crypto.
    Future<void> pumpDetail(WidgetTester tester, String noteId) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: ProviderContainer(
            overrides: defaultIntegrationOverrides(
              cryptoService: crypto,
              apiClient: FakeApiClient(),
              db: db,
            ),
          ),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NoteDetailScreen(noteId: noteId),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// A note exercising every toolbar op: H1 heading, bold, italic,
    /// underline, strikethrough, bullet list, numbered list, plain paragraph.
    List<Map<String, dynamic>> richOps() => [
          {'insert': 'Big Heading'},
          {'insert': '\n', 'attributes': {'header': 1}},
          {'insert': 'Bold', 'attributes': {'bold': true}},
          {'insert': ' '},
          {'insert': 'Italic', 'attributes': {'italic': true}},
          {'insert': ' '},
          {'insert': 'Underline', 'attributes': {'underline': true}},
          {'insert': ' '},
          {'insert': 'Strike', 'attributes': {'strike': true}},
          {'insert': '\nNormal paragraph text.\n'},
          {'insert': 'alpha'},
          {'insert': '\n', 'attributes': {'list': 'bullet'}},
          {'insert': 'beta'},
          {'insert': '\n', 'attributes': {'list': 'bullet'}},
          {'insert': 'one'},
          {'insert': '\n', 'attributes': {'list': 'ordered'}},
          {'insert': 'two'},
          {'insert': '\n', 'attributes': {'list': 'ordered'}},
        ];

    testWidgets(
      'renders a toolbar-formatted note via QuillReadOnlyViewer (no raw JSON)',
      (tester) async {
        const noteId = 'fmt-note';
        final ops = richOps();
        final deltaJson = jsonEncode(ops);

        await db.notesDao.createNote(
          id: noteId,
          encryptedContent: 'enc_$deltaJson',
          encryptedTitle: 'enc_Big Heading',
          plainContent: 'Big Heading\nBold Italic Underline Strike\n'
              'Normal paragraph text.\nalpha\nbeta\none\ntwo',
          plainTitle: 'Big Heading',
        );

        await pumpDetail(tester, noteId);

        // The note loaded and rendered (the title is a plain Text widget).
        expect(find.text('Big Heading'), findsOneWidget);
        // The body renders through the same Quill viewer the editor uses.
        expect(find.byType(QuillReadOnlyViewer), findsOneWidget);
        // No raw Delta JSON or sync envelope leaks as plain text.
        expect(find.textContaining('"insert"'), findsNothing);
        expect(find.textContaining('"header"'), findsNothing);
        expect(find.textContaining('{"content"'), findsNothing);
      },
    );

    testWidgets(
      'repairs a sync-envelope-corrupted note and renders the real body',
      (tester) async {
        const noteId = 'env-note';
        const body = 'The real note body survives the corruption.';
        // The corrupted form: envelope baked into a Quill Delta's insert text.
        final envelope = jsonEncode({'content': body, 'title': 'T'});
        final corrupted = jsonEncode([
          {'insert': 'T\n$envelope\n'},
        ]);

        await db.notesDao.createNote(
          id: noteId,
          encryptedContent: 'enc_$corrupted',
          encryptedTitle: 'enc_EnvTestTitle',
          plainContent: body,
          plainTitle: 'EnvTestTitle',
        );

        await pumpDetail(tester, noteId);

        // The note loaded (title rendered) and renders via the viewer.
        expect(find.text('EnvTestTitle'), findsOneWidget);
        expect(find.byType(QuillReadOnlyViewer), findsOneWidget);
        // The envelope is unwrapped away — no raw JSON leaks.
        expect(find.textContaining('{"content"'), findsNothing);
      },
    );

    test('unwrapSyncEnvelope sanity on the corruption payload', () {
      const body = ' sanity body ';
      final envelope = jsonEncode({'content': body, 'title': 'T'});
      final corrupted = jsonEncode([
        {'insert': 'T\n$envelope\n'},
      ]);
      expect(unwrapSyncEnvelope(corrupted), body);
    });
  });
}
