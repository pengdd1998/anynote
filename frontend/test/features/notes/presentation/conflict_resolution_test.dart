import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/sync/sync_engine.dart';
import 'package:anynote/features/notes/presentation/conflict_resolution_screen.dart';
import 'package:anynote/l10n/app_localizations.dart';

void main() {
  group('ConflictResolutionScreen', () {
    Widget buildScreen([List<SyncConflict>? conflicts]) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ConflictResolutionScreen(
          conflicts: conflicts ?? [],
        ),
      );
    }

    testWidgets('renders empty state when no conflicts', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byType(ConflictResolutionScreen), findsOneWidget);
    });

    testWidgets('renders conflict cards when conflicts exist', (tester) async {
      final conflicts = [
        SyncConflict(itemId: 'item-123-abc', serverVersion: 5),
      ];
      await tester.pumpWidget(buildScreen(conflicts));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('shows truncated item ID', (tester) async {
      final conflicts = [
        SyncConflict(itemId: 'item-12345678-abc', serverVersion: 5),
      ];
      await tester.pumpWidget(buildScreen(conflicts));
      await tester.pumpAndSettle();

      expect(find.textContaining('item-123'), findsOneWidget);
    });

    testWidgets('shows Keep Local button', (tester) async {
      final conflicts = [
        SyncConflict(itemId: 'item-1', serverVersion: 5),
      ];
      await tester.pumpWidget(buildScreen(conflicts));
      await tester.pumpAndSettle();

      expect(find.text('Keep Local'), findsOneWidget);
    });

    testWidgets('shows Keep Server button', (tester) async {
      final conflicts = [
        SyncConflict(itemId: 'item-1', serverVersion: 5),
      ];
      await tester.pumpWidget(buildScreen(conflicts));
      await tester.pumpAndSettle();

      expect(find.text('Keep Server'), findsOneWidget);
    });

    testWidgets('shows Keep Both button', (tester) async {
      final conflicts = [
        SyncConflict(itemId: 'item-1', serverVersion: 5),
      ];
      await tester.pumpWidget(buildScreen(conflicts));
      await tester.pumpAndSettle();

      expect(find.text('Keep Both'), findsOneWidget);
    });

    testWidgets('renders multiple conflicts', (tester) async {
      final conflicts = [
        SyncConflict(itemId: 'item-1', serverVersion: 5),
        SyncConflict(itemId: 'item-2', serverVersion: 3),
        SyncConflict(itemId: 'item-3', serverVersion: 7),
      ];
      await tester.pumpWidget(buildScreen(conflicts));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(3));
    });
  });

  group('SyncConflict', () {
    test('stores itemId and serverVersion', () {
      final conflict = SyncConflict(itemId: 'abc', serverVersion: 42);
      expect(conflict.itemId, 'abc');
      expect(conflict.serverVersion, 42);
    });
  });

  group('SyncResult', () {
    test('hasConflicts returns false when empty', () {
      final result = SyncResult(
        pulledCount: 5,
        pushedCount: 3,
      );
      expect(result.hasConflicts, isFalse);
    });

    test('hasConflicts returns true when present', () {
      final result = SyncResult(
        pulledCount: 5,
        pushedCount: 3,
        conflicts: [SyncConflict(itemId: 'x', serverVersion: 1)],
      );
      expect(result.hasConflicts, isTrue);
    });
  });
}
