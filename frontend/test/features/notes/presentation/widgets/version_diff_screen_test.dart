import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/notes/domain/text_diff.dart';
import 'package:anynote/features/notes/presentation/widgets/version_diff_screen.dart';
import 'package:anynote/l10n/app_localizations.dart';

import '../../../../helpers/test_app_helper.dart';

// ---------------------------------------------------------------------------
// Tests -- TextDiff (pure logic, no widget)
// ---------------------------------------------------------------------------

void main() {
  group('TextDiff', () {
    test('computes identical content as no changes', () {
      final diff = TextDiff.compute('Hello\nWorld', 'Hello\nWorld');
      expect(diff.isIdentical, isTrue);
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(0));
    });

    test('computes added lines correctly', () {
      final diff = TextDiff.compute('Hello', 'Hello\nWorld');
      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(1));
      expect(diff.linesRemoved, equals(0));
    });

    test('computes removed lines correctly', () {
      final diff = TextDiff.compute('Hello\nWorld', 'Hello');
      expect(diff.isIdentical, isFalse);
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(1));
    });

    test('computes mixed additions and removals', () {
      final diff = TextDiff.compute('A\nB\nC', 'A\nX\nC');
      expect(diff.linesAdded, equals(1));
      expect(diff.linesRemoved, equals(1));
    });

    test('handles empty old text', () {
      final diff = TextDiff.compute('', 'Hello\nWorld');
      expect(diff.linesAdded, equals(2));
      expect(diff.linesRemoved, equals(0));
    });

    test('handles empty new text', () {
      final diff = TextDiff.compute('Hello\nWorld', '');
      expect(diff.linesAdded, equals(0));
      expect(diff.linesRemoved, equals(2));
    });

    test('handles both texts empty', () {
      final diff = TextDiff.compute('', '');
      expect(diff.isIdentical, isTrue);
      expect(diff.lines, isEmpty);
    });

    test('diff lines have correct type classification', () {
      final diff = TextDiff.compute('A\nB', 'A\nC');
      expect(diff.lines.length, equals(3));

      final types = diff.lines.map((l) => l.type).toList();
      expect(types, contains(DiffType.unchanged));
      expect(types, contains(DiffType.removed));
      expect(types, contains(DiffType.added));
    });

    test('linesUnchanged counts match', () {
      final diff = TextDiff.compute('A\nB\nC', 'A\nB\nC');
      expect(diff.linesUnchanged, equals(3));
    });

    test('DiffLine toString uses correct prefixes', () {
      expect(
        const DiffLine(text: 'hello', type: DiffType.added).toString(),
        equals('+ hello'),
      );
      expect(
        const DiffLine(text: 'world', type: DiffType.removed).toString(),
        equals('- world'),
      );
      expect(
        const DiffLine(text: 'same', type: DiffType.unchanged).toString(),
        equals('  same'),
      );
    });

    test('preserves line order in diff output', () {
      final diff = TextDiff.compute(
        'Line A\nLine B\nLine C',
        'Line A\nLine X\nLine C',
      );

      // Lines should be ordered: unchanged A, added X, removed B, unchanged C.
      // The LCS backtrack produces additions before removals when table[i-1][j]
      // < table[i][j-1].
      expect(diff.lines[0].type, equals(DiffType.unchanged));
      expect(diff.lines[0].text, equals('Line A'));
      expect(diff.lines[1].type, equals(DiffType.added));
      expect(diff.lines[1].text, equals('Line X'));
      expect(diff.lines[2].type, equals(DiffType.removed));
      expect(diff.lines[2].text, equals('Line B'));
      expect(diff.lines[3].type, equals(DiffType.unchanged));
      expect(diff.lines[3].text, equals('Line C'));
    });

    test('handles completely different texts', () {
      final diff = TextDiff.compute('AAA', 'BBB');
      expect(diff.linesAdded, equals(1));
      expect(diff.linesRemoved, equals(1));
      expect(diff.linesUnchanged, equals(0));
    });

    test('handles multi-line addition', () {
      final diff = TextDiff.compute('A', 'A\nB\nC\nD');
      expect(diff.linesAdded, equals(3));
      expect(diff.linesRemoved, equals(0));
    });

    test('isIdentical returns true for empty diffs', () {
      final diff = TextDiff.compute('', '');
      expect(diff.isIdentical, isTrue);
    });
  });

  group('VersionDiffScreen', () {
    testWidgets('renders version diff title in app bar', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...defaultProviderOverrides(db: db),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: VersionDiffScreen(
              noteId: 'note-1',
              olderVersionId: 'ver-old',
              newerVersionId: 'ver-new',
            ),
          ),
        ),
      );

      // Allow async loading to complete.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The app bar should always show "Version Diff" regardless of load state.
      expect(find.text('Version Diff'), findsOneWidget);

      // Should be a Scaffold widget.
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows an error or retry UI when versions cannot be loaded',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...defaultProviderOverrides(db: db),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: VersionDiffScreen(
              noteId: 'note-1',
              olderVersionId: 'nonexistent-old',
              newerVersionId: 'nonexistent-new',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // When versions fail to load, the screen shows either the specific
      // "Failed to load versions" message or a generic error message,
      // plus a "Retry" button.
      expect(find.text('Retry'), findsOneWidget);

      // Should show an error icon.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('has AppBar with version diff title', (tester) async {
      final db = createTestDatabase();
      addTearDown(() => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...defaultProviderOverrides(db: db),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: VersionDiffScreen(
              noteId: 'note-1',
              olderVersionId: 'ver-old',
              newerVersionId: 'ver-new',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
