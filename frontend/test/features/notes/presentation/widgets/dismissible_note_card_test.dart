import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/dismissible_note_card.dart';
import 'package:anynote/features/notes/presentation/widgets/note_card.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

Note _defaultNote({
  String id = 'note-1',
  String? plainTitle = 'Test Note',
  String? plainContent = 'Content for dismissible card.',
  bool isPinned = false,
  bool isSynced = false,
}) =>
    Note(
      id: id,
      encryptedContent: 'enc_content',
      encryptedTitle: 'enc_title',
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 4, 22),
      isSynced: isSynced,
      isPinned: isPinned,
      plainContent: plainContent,
      plainTitle: plainTitle,
    );

Tag _makeTag({required String id, String? plainName}) => Tag(
      id: id,
      encryptedName: 'enc_$id',
      plainName: plainName,
      version: 1,
      isSynced: false,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps a [DismissibleNoteCard] inside a localized [MaterialApp] with a
/// real test database for DAO operations.
Future<AppDatabase> pumpDismissibleCard(
  WidgetTester tester, {
  Note? note,
  bool isGrid = false,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onDeleted,
}) async {
  final db = createTestDatabase();
  final n = note ?? _defaultNote();

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: DismissibleNoteCard(
          note: n,
          db: db,
          isGrid: isGrid,
          time: 'just now',
          tags: [_makeTag(id: 't1', plainName: 'Work')],
          isSelected: false,
          onTap: onTap ?? () {},
          onLongPress: onLongPress ?? () {},
          onDeleted: onDeleted,
          untitled: 'Untitled',
        ),
      ),
    ),
  );

  return db;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DismissibleNoteCard', () {
    testWidgets('renders NoteCard in list layout when isGrid is false',
        (tester) async {
      final db = await pumpDismissibleCard(tester, isGrid: false);
      addTearDown(() async => db.close());

      final noteCard = tester.widget<NoteCard>(find.byType(NoteCard));
      expect(noteCard.layout, NoteCardLayout.list);
    });

    testWidgets('renders NoteCard in grid layout when isGrid is true',
        (tester) async {
      final db = await pumpDismissibleCard(tester, isGrid: true);
      addTearDown(() async => db.close());

      final noteCard = tester.widget<NoteCard>(find.byType(NoteCard));
      expect(noteCard.layout, NoteCardLayout.grid);
    });

    testWidgets('renders note title', (tester) async {
      final db = await pumpDismissibleCard(
        tester,
        note: _defaultNote(plainTitle: 'Dismissible Title'),
      );
      addTearDown(() async => db.close());

      expect(find.text('Dismissible Title'), findsOneWidget);
    });

    testWidgets('renders untitled fallback', (tester) async {
      final db = await pumpDismissibleCard(
        tester,
        note: _defaultNote(plainTitle: null),
      );
      addTearDown(() async => db.close());

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('uses Dismissible widget', (tester) async {
      final db = await pumpDismissibleCard(tester);
      addTearDown(() async => db.close());

      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      final db = await pumpDismissibleCard(
        tester,
        onTap: () => tapped = true,
      );
      addTearDown(() async => db.close());

      // Tap on the card content text (which is inside the Dismissible child).
      await tester.tap(find.text('Test Note'));
      expect(tapped, isTrue);
    });

    testWidgets('fires onLongPress callback', (tester) async {
      var longPressed = false;
      final db = await pumpDismissibleCard(
        tester,
        onLongPress: () => longPressed = true,
      );
      addTearDown(() async => db.close());

      // Long press on the card content text.
      await tester.longPress(find.text('Test Note'));
      expect(longPressed, isTrue);
    });

    testWidgets('renders time string', (tester) async {
      final db = await pumpDismissibleCard(tester);
      addTearDown(() async => db.close());

      expect(find.text('just now'), findsOneWidget);
    });

    testWidgets('renders tags', (tester) async {
      final db = await pumpDismissibleCard(tester);
      addTearDown(() async => db.close());

      expect(find.text('Work'), findsOneWidget);
    });
  });
}
