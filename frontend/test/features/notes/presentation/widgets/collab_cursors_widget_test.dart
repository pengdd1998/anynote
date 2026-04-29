import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/collab/ws_client.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/notes/presentation/widgets/collab_cursors_widget.dart';
import 'package:anynote/main.dart' show apiClientProvider;

// ---------------------------------------------------------------------------
// Mock WSClient that allows simulating incoming messages.
// ---------------------------------------------------------------------------
class MockWSClient extends WSClient {
  final _messageController = StreamController<WSMessage>.broadcast();
  final _stateController = StreamController<WSConnectionState>.broadcast();

  final WSConnectionState _currentState = WSConnectionState.connected;

  MockWSClient()
      : super(baseUrl: 'ws://localhost:8080/api/v1/ws', token: 'test-token');

  @override
  Stream<WSMessage> get messages => _messageController.stream;

  @override
  Stream<WSConnectionState> get connectionState => _stateController.stream;

  @override
  WSConnectionState get state => _currentState;

  @override
  void joinRoom(String noteId) {}

  @override
  void leaveRoom(String noteId) {}

  @override
  void dispose() {
    _messageController.close();
    _stateController.close();
  }

  void simulateMessage(WSMessage msg) {
    _messageController.add(msg);
  }
}

// ---------------------------------------------------------------------------
// Mock WSClientNotifier that provides the mock client.
// ---------------------------------------------------------------------------
class MockWSClientNotifier extends StateNotifier<WSConnectionState>
    implements WSClientNotifier {
  final MockWSClient _mockClient;

  MockWSClientNotifier(this._mockClient) : super(WSConnectionState.connected);

  @override
  WSClient get client => _mockClient;

  @override
  Future<void> connect(String token) async {}

  @override
  void disconnect() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Stub ApiClient for the wsClientProvider dependency.
// ---------------------------------------------------------------------------
class StubApiClient extends ApiClient {
  StubApiClient() : super(baseUrl: 'http://localhost:8080');
}

void main() {
  late MockWSClient mockClient;
  late ProviderContainer container;

  setUp(() {
    mockClient = MockWSClient();
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(StubApiClient()),
        wsClientProvider.overrideWith((ref) {
          return MockWSClientNotifier(mockClient);
        }),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    mockClient.dispose();
  });

  // ===========================================================================
  // Rendering tests
  // ===========================================================================

  testWidgets('renders child widget', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: CollabCursorsWidget(
              noteId: 'note-1',
              child: Text('Editor content'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Editor content'), findsOneWidget);
  });

  testWidgets('shows no cursors initially', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: CollabCursorsWidget(
              noteId: 'note-1',
              child: Text('Editor'),
            ),
          ),
        ),
      ),
    );

    // No cursor tooltips should be present initially.
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets(
      'shows cursor when WS cursor message is received for correct room',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CollabCursorsWidget(
                noteId: 'note-1',
                editorContent: 'hello world',
                child: Text('Editor'),
              ),
            ),
          ),
        ),
      ),
    );

    // Simulate a cursor message for the correct room.
    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'user_id': 'u1',
        'username': 'Alice',
        'position': 3,
      }),
    );

    await tester.pumpAndSettle();

    // The cursor overlay should now render a tooltip for Alice.
    expect(find.byTooltip('Alice'), findsOneWidget);
  });

  testWidgets('ignores cursor messages for other rooms', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CollabCursorsWidget(
                noteId: 'note-1',
                editorContent: 'hello world',
                child: Text('Editor'),
              ),
            ),
          ),
        ),
      ),
    );

    // Simulate a cursor message for a different room.
    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-other',
        'user_id': 'u1',
        'username': 'Alice',
        'position': 3,
      }),
    );

    await tester.pumpAndSettle();

    // No cursor tooltips should appear.
    expect(find.byTooltip('Alice'), findsNothing);
  });

  testWidgets('removes old cursor and shows updated position for same user',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CollabCursorsWidget(
                noteId: 'note-1',
                editorContent: 'hello world from test',
                child: Text('Editor'),
              ),
            ),
          ),
        ),
      ),
    );

    // First cursor message for Alice at position 0.
    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'user_id': 'u1',
        'username': 'Alice',
        'position': 0,
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Alice'), findsOneWidget);

    // Second cursor message for Alice at position 5.
    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'user_id': 'u1',
        'username': 'Alice',
        'position': 5,
      }),
    );
    await tester.pumpAndSettle();

    // Should still have exactly one tooltip for Alice (replaced, not duplicated).
    expect(find.byTooltip('Alice'), findsOneWidget);
  });

  testWidgets('shows multiple cursors from different users', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CollabCursorsWidget(
                noteId: 'note-1',
                editorContent: 'hello world test content',
                child: Text('Editor'),
              ),
            ),
          ),
        ),
      ),
    );

    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'user_id': 'u1',
        'username': 'Alice',
        'position': 0,
      }),
    );
    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'user_id': 'u2',
        'username': 'Bob',
        'position': 5,
      }),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Alice'), findsOneWidget);
    expect(find.byTooltip('Bob'), findsOneWidget);
  });

  testWidgets('ignores non-cursor WS messages', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CollabCursorsWidget(
                noteId: 'note-1',
                editorContent: 'hello world',
                child: Text('Editor'),
              ),
            ),
          ),
        ),
      ),
    );

    // Simulate an edit message (not a cursor message).
    mockClient.simulateMessage(
      WSMessage(WSMessageType.edit, {
        'room': 'note-1',
        'ops': [],
      }),
    );
    await tester.pumpAndSettle();

    // No cursors should be shown.
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('disposes subscription on unmount', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CollabCursorsWidget(
                noteId: 'note-1',
                editorContent: 'hello',
                child: Text('Editor'),
              ),
            ),
          ),
        ),
      ),
    );

    // Mount the widget.
    expect(find.text('Editor'), findsOneWidget);

    // Remove the widget, triggering dispose.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Text('Replaced'),
          ),
        ),
      ),
    );

    // After unmount, sending a message should not cause errors.
    // The stream subscription should have been cancelled.
    mockClient.simulateMessage(
      WSMessage(WSMessageType.cursor, {
        'room': 'note-1',
        'user_id': 'u1',
        'username': 'Alice',
        'position': 0,
      }),
    );
    await tester.pumpAndSettle();

    // No crash -- the test passing is the verification.
    expect(find.text('Replaced'), findsOneWidget);
  });
}
