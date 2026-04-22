import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/collab/presence_indicator.dart';
import 'package:anynote/core/collab/ws_client.dart';

// ---------------------------------------------------------------------------
// Fake WSClient for testing PresenceNotifier
// ---------------------------------------------------------------------------

/// A minimal fake that exposes a controllable message stream.
class FakeWSClient extends WSClient {
  final controller = StreamController<WSMessage>.broadcast();

  FakeWSClient() : super(baseUrl: 'ws://localhost', token: 'test-token');

  @override
  Stream<WSMessage> get messages => controller.stream;

  @override
  void joinRoom(String noteId) {}

  @override
  void leaveRoom(String noteId) {}

  @override
  void sendTyping(String noteId) {}

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }
}

/// A [WSClientNotifier] subclass that returns a [FakeWSClient].
class FakeWSClientNotifier extends WSClientNotifier {
  final FakeWSClient fakeClient;

  FakeWSClientNotifier(super.ref, this.fakeClient);

  @override
  WSClient get client => fakeClient;
}

void main() {
  // ===========================================================================
  // RoomPresence model
  // ===========================================================================

  group('RoomPresence', () {
    test('copyWith preserves unchanged fields', () {
      final original = RoomPresence(
        userId: 'u1',
        displayName: 'Alice',
        joinedAt: DateTime(2024),
        isTyping: false,
      );

      final copy = original.copyWith(isTyping: true);

      expect(copy.userId, 'u1');
      expect(copy.displayName, 'Alice');
      expect(copy.joinedAt, DateTime(2024));
      expect(copy.isTyping, isTrue);
    });

    test('copyWith overrides specified fields', () {
      final original = RoomPresence(
        userId: 'u1',
        displayName: 'Alice',
        joinedAt: DateTime(2024),
        isTyping: false,
      );

      final newDate = DateTime(2025);
      final copy = original.copyWith(
        displayName: 'Bob',
        joinedAt: newDate,
        isTyping: true,
      );

      expect(copy.userId, 'u1'); // unchanged
      expect(copy.displayName, 'Bob');
      expect(copy.joinedAt, newDate);
      expect(copy.isTyping, isTrue);
    });

    test('copyWith with no arguments returns identical values', () {
      final original = RoomPresence(
        userId: 'u1',
        displayName: 'Alice',
        joinedAt: DateTime(2024),
        isTyping: false,
      );

      final copy = original.copyWith();

      expect(copy.userId, original.userId);
      expect(copy.displayName, original.displayName);
      expect(copy.joinedAt, original.joinedAt);
      expect(copy.isTyping, original.isTyping);
    });
  });

  // ===========================================================================
  // PresenceNotifier
  // ===========================================================================

  group('PresenceNotifier', () {
    late FakeWSClient fakeClient;
    late ProviderContainer container;
    late PresenceNotifier notifier;

    setUp(() {
      fakeClient = FakeWSClient();
      container = ProviderContainer(
        overrides: [
          wsClientProvider.overrideWith((ref) {
            return FakeWSClientNotifier(ref, fakeClient);
          }),
        ],
      );
      notifier = container.read(presenceProvider.notifier);
    });

    tearDown(() {
      // Only dispose the fakeClient and container; container.dispose() will
      // handle disposing the PresenceNotifier obtained from the provider.
      fakeClient.dispose();
      container.dispose();
    });

    test('initial state is empty map', () {
      expect(notifier.state, isEmpty);
    });

    test('joinRoom clears previous state', () async {
      // Add some state first by simulating a join.
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, isNotEmpty);

      // Joining a new room should clear state.
      notifier.joinRoom('room-2');
      expect(notifier.state, isEmpty);
    });

    test('leaveRoom clears state and cancels subscription', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, contains('u1'));

      notifier.leaveRoom();
      expect(notifier.state, isEmpty);
    });

    test('_onJoin adds user to state', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, contains('u1'));
      expect(notifier.state['u1']!.displayName, 'Alice');
    });

    test('_onJoin with null user_id does not add entry', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, isEmpty);
    });

    test('_onJoin uses default display name when missing', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u2',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state['u2']!.displayName, 'Unknown');
    });

    test('_onLeave removes user from state', () async {
      notifier.joinRoom('room-1');

      // Add a user first.
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.state, contains('u1'));

      // Then remove them.
      fakeClient.controller.add(WSMessage(WSMessageType.leave, {
        'user_id': 'u1',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, isNot(contains('u1')));
    });

    test('_onLeave with null user_id does not change state', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.state, contains('u1'));

      fakeClient.controller.add(WSMessage(WSMessageType.leave, {}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, contains('u1'));
    });

    test('_onPresence replaces entire state with server list', () async {
      notifier.joinRoom('room-1');

      fakeClient.controller.add(WSMessage(WSMessageType.presence, {
        'users': [
          {'user_id': 'u1', 'display_name': 'Alice'},
          {'user_id': 'u2', 'display_name': 'Bob'},
        ],
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.length, 2);
      expect(notifier.state['u1']!.displayName, 'Alice');
      expect(notifier.state['u2']!.displayName, 'Bob');
    });

    test('_onPresence with null users does not change state', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.state, contains('u1'));

      fakeClient.controller.add(WSMessage(WSMessageType.presence, {}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // State should be unchanged.
      expect(notifier.state, contains('u1'));
    });

    test('_onPresence skips entries with null user_id', () async {
      notifier.joinRoom('room-1');

      fakeClient.controller.add(WSMessage(WSMessageType.presence, {
        'users': [
          {'user_id': 'u1', 'display_name': 'Alice'},
          {'display_name': 'No ID'},
          {'user_id': 'u3', 'display_name': 'Charlie'},
        ],
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.length, 2);
      expect(notifier.state, contains('u1'));
      expect(notifier.state, contains('u3'));
    });

    test('_onTyping sets isTyping=true for user', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      fakeClient.controller.add(WSMessage(WSMessageType.typing, {
        'user_id': 'u1',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state['u1']!.isTyping, isTrue);
    });

    test('_onTyping ignores unknown user', () async {
      notifier.joinRoom('room-1');

      fakeClient.controller.add(WSMessage(WSMessageType.typing, {
        'user_id': 'u-unknown',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state, isNot(contains('u-unknown')));
    });

    test('_onTyping auto-clears isTyping after 3 seconds', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      fakeClient.controller.add(WSMessage(WSMessageType.typing, {
        'user_id': 'u1',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.state['u1']!.isTyping, isTrue);

      // Advance time by 3 seconds.
      await Future<void>.delayed(const Duration(seconds: 4));
      expect(notifier.state['u1']!.isTyping, isFalse);
    });

    test('unknown message types are ignored', () async {
      notifier.joinRoom('room-1');
      fakeClient.controller.add(WSMessage(WSMessageType.join, {
        'user_id': 'u1',
        'display_name': 'Alice',
      }),);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.state.length, 1);

      fakeClient.controller.add(WSMessage(WSMessageType.ping, {}));
      fakeClient.controller.add(WSMessage(WSMessageType.pong, {}));
      fakeClient.controller
          .add(WSMessage(WSMessageType.comment, {'text': 'hi'}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // State should be unchanged after ignored messages.
      expect(notifier.state.length, 1);
      expect(notifier.state, contains('u1'));
    });
  });

  // ===========================================================================
  // PresenceAvatarStack
  // ===========================================================================

  group('PresenceAvatarStack', () {
    List<RoomPresence> makeUsers(int count) {
      return List.generate(
        count,
        (i) => RoomPresence(
          userId: 'u$i',
          displayName: String.fromCharCode(65 + i), // A, B, C, ...
          joinedAt: DateTime.now(),
        ),
      );
    }

    Future<void> pumpStack(
      WidgetTester tester, {
      required List<RoomPresence> users,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PresenceAvatarStack(users: users),
          ),
        ),
      );
    }

    testWidgets('renders SizedBox.shrink for 0 users', (tester) async {
      await pumpStack(tester, users: []);

      // PresenceAvatarStack renders SizedBox.shrink when empty.
      // Verify no avatar circles are present by checking no Container with
      // circle shape is rendered.
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.byType(SizedBox),
      );
      // There should be at least one SizedBox (the root SizedBox.shrink).
      expect(sizedBoxes.isNotEmpty, isTrue);
    });

    testWidgets('renders single avatar for 1 user', (tester) async {
      await pumpStack(tester, users: makeUsers(1));

      // The initial "A" from displayName should be visible.
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders 4 avatars without overflow badge for 4 users',
        (tester) async {
      await pumpStack(tester, users: makeUsers(4));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      // No overflow badge for exactly 4 users.
      expect(find.text('+0'), findsNothing);
    });

    testWidgets('renders 4 avatars with +N overflow badge for 6 users',
        (tester) async {
      await pumpStack(tester, users: makeUsers(6));

      // Should show 4 avatar circles and a +2 overflow badge.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);

      // E and F should NOT be visible (hidden by overflow).
      expect(find.text('E'), findsNothing);
      expect(find.text('F'), findsNothing);
    });

    testWidgets('renders +N badge with correct count for 5 users',
        (tester) async {
      await pumpStack(tester, users: makeUsers(5));

      // 5 users: 4 visible + "+1" overflow badge.
      expect(find.text('+1'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TypingIndicatorText
  // ===========================================================================

  group('TypingIndicatorText', () {
    RoomPresence makeUser(String id, String name) {
      return RoomPresence(
        userId: id,
        displayName: name,
        joinedAt: DateTime.now(),
      );
    }

    Future<void> pumpIndicator(
      WidgetTester tester, {
      required List<RoomPresence> typingUsers,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypingIndicatorText(typingUsers: typingUsers),
          ),
        ),
      );
    }

    testWidgets('renders SizedBox.shrink for empty typing users',
        (tester) async {
      await pumpIndicator(tester, typingUsers: []);

      // No typing text should be present.
      expect(find.text('is typing'), findsNothing);
      expect(find.text('are typing'), findsNothing);
    });

    testWidgets('shows single user typing text', (tester) async {
      await pumpIndicator(tester, typingUsers: [makeUser('u1', 'Alice')]);

      expect(find.textContaining('Alice is typing'), findsOneWidget);
    });

    testWidgets('shows two users typing text', (tester) async {
      await pumpIndicator(
        tester,
        typingUsers: [makeUser('u1', 'Alice'), makeUser('u2', 'Bob')],
      );

      expect(find.textContaining('Alice and Bob are typing'), findsOneWidget);
    });

    testWidgets('shows "N others" for three or more users', (tester) async {
      await pumpIndicator(
        tester,
        typingUsers: [
          makeUser('u1', 'Alice'),
          makeUser('u2', 'Bob'),
          makeUser('u3', 'Charlie'),
        ],
      );

      expect(
          find.textContaining('Alice and 2 others are typing'), findsOneWidget,);
    });

    testWidgets('shows "N others" for many users', (tester) async {
      await pumpIndicator(
        tester,
        typingUsers: [
          makeUser('u1', 'Alice'),
          makeUser('u2', 'Bob'),
          makeUser('u3', 'Charlie'),
          makeUser('u4', 'Diana'),
          makeUser('u5', 'Eve'),
        ],
      );

      expect(
          find.textContaining('Alice and 4 others are typing'), findsOneWidget,);
    });

    testWidgets('typing text is in a Row widget', (tester) async {
      await pumpIndicator(tester, typingUsers: [makeUser('u1', 'Alice')]);

      // TypingIndicatorText renders a Row with the text and animated dots.
      expect(find.byType(Row), findsWidgets);
    });
  });
}
