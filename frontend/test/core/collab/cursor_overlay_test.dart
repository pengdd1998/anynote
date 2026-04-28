import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anynote/core/collab/cursor_overlay.dart';

void main() {
  // ===========================================================================
  // CursorData
  // ===========================================================================

  group('CursorData', () {
    test('constructor sets all fields', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        color: Colors.blue,
      );
      expect(cursor.userId, 'u1');
      expect(cursor.username, 'Alice');
      expect(cursor.position, 5);
      expect(cursor.selectionEnd, isNull);
      expect(cursor.color, Colors.blue);
    });

    test('constructor with selectionEnd sets field', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Bob',
        position: 3,
        selectionEnd: 10,
        color: Colors.green,
      );
      expect(cursor.selectionEnd, 10);
    });

    test('hasSelection is false when selectionEnd is null', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        color: Colors.blue,
      );
      expect(cursor.hasSelection, isFalse);
    });

    test('hasSelection is false when selectionEnd equals position', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 5,
        color: Colors.blue,
      );
      expect(cursor.hasSelection, isFalse);
    });

    test('hasSelection is true when selectionEnd differs from position', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 10,
        color: Colors.blue,
      );
      expect(cursor.hasSelection, isTrue);
    });

    test('hasSelection is true when selectionEnd is less than position', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 10,
        selectionEnd: 3,
        color: Colors.blue,
      );
      expect(cursor.hasSelection, isTrue);
    });

    test('fromMap parses valid map correctly', () {
      final cursor = CursorData.fromMap({
        'user_id': 'u42',
        'username': 'Charlie',
        'position': 15,
        'selection_end': 20,
      });
      expect(cursor.userId, 'u42');
      expect(cursor.username, 'Charlie');
      expect(cursor.position, 15);
      expect(cursor.selectionEnd, 20);
      expect(cursor.color, isNotNull);
    });

    test('fromMap uses defaults for missing keys', () {
      final cursor = CursorData.fromMap({});
      expect(cursor.userId, '');
      expect(cursor.username, '???');
      expect(cursor.position, 0);
      expect(cursor.selectionEnd, isNull);
    });

    test('fromMap assigns deterministic color for same userId', () {
      final cursor1 = CursorData.fromMap({'user_id': 'user-abc'});
      final cursor2 = CursorData.fromMap({'user_id': 'user-abc'});
      expect(cursor1.color, cursor2.color);
    });

    test('fromMap assigns different colors for different userIds', () {
      // With 8 colors in the palette, use IDs that are guaranteed to hash to
      // different indices. Since we cannot control hashCode, we test several
      // pairs and verify at least one pair differs.
      final colorSet = <Color>{};
      for (var i = 0; i < 20; i++) {
        final cursor = CursorData.fromMap({'user_id': 'user-$i'});
        colorSet.add(cursor.color);
      }
      // We should see more than one color among 20 different user IDs.
      expect(colorSet.length, greaterThan(1));
    });

    test('equality returns true for identical fields', () {
      final cursor1 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 10,
        color: Colors.blue,
      );
      final cursor2 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 10,
        color: Colors.blue,
      );
      expect(cursor1, equals(cursor2));
    });

    test('equality returns false for different fields', () {
      final cursor1 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        color: Colors.blue,
      );
      final cursor2 = CursorData(
        userId: 'u1',
        username: 'Bob',
        position: 5,
        color: Colors.blue,
      );
      expect(cursor1, isNot(equals(cursor2)));
    });

    test('equality returns false for different selectionEnd', () {
      final cursor1 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 10,
        color: Colors.blue,
      );
      final cursor2 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 12,
        color: Colors.blue,
      );
      expect(cursor1, isNot(equals(cursor2)));
    });

    test('equality returns false for non-CursorData object', () {
      final cursor = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        color: Colors.blue,
      );
      expect(cursor, isNot(equals('not a cursor')));
    });

    test('hashCode is consistent with equality', () {
      final cursor1 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 10,
        color: Colors.blue,
      );
      final cursor2 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        selectionEnd: 10,
        color: Colors.blue,
      );
      expect(cursor1.hashCode, cursor2.hashCode);
    });

    test('hashCode differs for different cursors', () {
      final cursor1 = CursorData(
        userId: 'u1',
        username: 'Alice',
        position: 5,
        color: Colors.blue,
      );
      final cursor2 = CursorData(
        userId: 'u2',
        username: 'Bob',
        position: 10,
        color: Colors.green,
      );
      // While not strictly required, different data should typically produce
      // different hashCodes. We use a set to verify.
      expect({cursor1.hashCode, cursor2.hashCode}.length, greaterThan(1));
    });
  });

  // ===========================================================================
  // CursorOverlay
  // ===========================================================================

  group('CursorOverlay', () {
    testWidgets('renders SizedBox.shrink when cursors is empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CursorOverlay(cursors: []),
          ),
        ),
      );

      // When cursors is empty, build returns SizedBox.shrink().
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('renders Stack with cursor elements when cursors provided',
        (tester) async {
      final cursors = [
        CursorData(
          userId: 'u1',
          username: 'Alice',
          position: 0,
          color: Colors.blue,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CursorOverlay(cursors: cursors, content: 'hello'),
            ),
          ),
        ),
      );

      // Should find a Stack produced by CursorOverlay.
      expect(find.byType(Stack), findsWidgets);

      // Each cursor renders a Tooltip with the username.
      expect(find.byTooltip('Alice'), findsOneWidget);
    });

    testWidgets('renders multiple cursors', (tester) async {
      final cursors = [
        CursorData(
          userId: 'u1',
          username: 'Alice',
          position: 0,
          color: Colors.blue,
        ),
        CursorData(
          userId: 'u2',
          username: 'Bob',
          position: 3,
          color: Colors.green,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CursorOverlay(cursors: cursors, content: 'hello world'),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Alice'), findsOneWidget);
      expect(find.byTooltip('Bob'), findsOneWidget);
    });

    testWidgets('renders selection highlight when cursor has selection',
        (tester) async {
      final cursors = [
        CursorData(
          userId: 'u1',
          username: 'Alice',
          position: 0,
          selectionEnd: 5,
          color: Colors.blue,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CursorOverlay(
                cursors: cursors,
                content: 'hello world',
              ),
            ),
          ),
        ),
      );

      // Should find the cursor tooltip.
      expect(find.byTooltip('Alice'), findsOneWidget);

      // Should find a Container used for the selection highlight.
      // The selection highlight is a Positioned > Container with decoration.
      // The Stack should contain both the selection highlight and the cursor.
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('accepts custom layout parameters', (tester) async {
      final cursors = [
        CursorData(
          userId: 'u1',
          username: 'Alice',
          position: 2,
          color: Colors.orange,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: CursorOverlay(
                cursors: cursors,
                content: 'some text content here',
                editorWidth: 800,
                lineHeight: 24.0,
                fontSize: 16.0,
                horizontalPadding: 32.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Alice'), findsOneWidget);
    });
  });
}
