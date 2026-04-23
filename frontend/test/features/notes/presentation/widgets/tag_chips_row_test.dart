import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/features/notes/presentation/widgets/tag_chips_row.dart';
import 'package:anynote/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<void> pumpTagChipsRow(
  WidgetTester tester, {
  List<Tag> tags = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: TagChipsRow(tags: tags),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

Tag _makeTag({required String id, String? plainName}) => Tag(
      id: id,
      encryptedName: 'enc_$id',
      plainName: plainName,
      version: 1,
      isSynced: false,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TagChipsRow', () {
    testWidgets('renders with no tags', (tester) async {
      await pumpTagChipsRow(tester, tags: []);
      // Should find the widget but no Chip children.
      expect(find.byType(TagChipsRow), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('renders tag chips with plainName', (tester) async {
      final tags = [
        _makeTag(id: 't1', plainName: 'Work'),
        _makeTag(id: 't2', plainName: 'Personal'),
      ];
      await pumpTagChipsRow(tester, tags: tags);

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('displays at most 3 tags', (tester) async {
      final tags = [
        _makeTag(id: 't1', plainName: 'A'),
        _makeTag(id: 't2', plainName: 'B'),
        _makeTag(id: 't3', plainName: 'C'),
        _makeTag(id: 't4', plainName: 'D'),
        _makeTag(id: 't5', plainName: 'E'),
      ];
      await pumpTagChipsRow(tester, tags: tags);

      // Only the first 3 tags should be rendered.
      expect(find.byType(Chip), findsNWidgets(3));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(find.text('E'), findsNothing);
    });

    testWidgets('shows fallback text when plainName is null', (tester) async {
      final tags = [_makeTag(id: 'tag-no-name')];
      await pumpTagChipsRow(tester, tags: tags);

      // When plainName is null, the chip should show '...'.
      expect(find.text('...'), findsOneWidget);
    });

    testWidgets('uses Wrap layout', (tester) async {
      await pumpTagChipsRow(tester, tags: [_makeTag(id: 't1', plainName: 'X')]);
      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
