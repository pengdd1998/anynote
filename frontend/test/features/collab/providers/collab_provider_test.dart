import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anynote/core/collab/crdt_editor_controller.dart';
import 'package:anynote/core/collab/crdt_text.dart';
import 'package:anynote/core/collab/ws_client.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/collab/providers/collab_provider.dart';
import 'package:anynote/main.dart' show apiClientProvider, databaseProvider;

// ---------------------------------------------------------------------------
// Mock WSClient that records method calls and allows simulating incoming
// messages and connection state changes.
// ---------------------------------------------------------------------------
class MockWSClient extends WSClient {
  final List<String> joinedRooms = [];
  final List<String> leftRooms = [];
  final List<(String, Map<String, dynamic>)> sentEdits = [];
  final List<(String, int)> sentCursors = [];

  final _messageController = StreamController<WSMessage>.broadcast();
  final _stateController = StreamController<WSConnectionState>.broadcast();

  WSConnectionState _currentState = WSConnectionState.connected;

  MockWSClient()
      : super(baseUrl: 'ws://localhost:8080/api/v1/ws', token: 'test-token');

  @override
  Stream<WSMessage> get messages => _messageController.stream;

  @override
  Stream<WSConnectionState> get connectionState => _stateController.stream;

  @override
  WSConnectionState get state => _currentState;

  @override
  void joinRoom(String noteId) {
    joinedRooms.add(noteId);
  }

  @override
  void leaveRoom(String noteId) {
    leftRooms.add(noteId);
  }

  @override
  void sendEdit(String noteId, Map<String, dynamic> editPayload) {
    sentEdits.add((noteId, editPayload));
  }

  @override
  void sendCursor(String noteId, int position) {
    sentCursors.add((noteId, position));
  }

  @override
  void dispose() {
    _messageController.close();
    _stateController.close();
  }

  // Helpers for tests to simulate events.

  void simulateMessage(WSMessage msg) {
    _messageController.add(msg);
  }

  void simulateConnectionState(WSConnectionState newState) {
    _currentState = newState;
    _stateController.add(newState);
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
  // Shared in-memory database for all collab provider tests.
  late AppDatabase testDb;

  setUp(() {
    testDb = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    CollabNotifier.resetSiteIdCache();
  });

  tearDown(() async {
    await testDb.close();
  });
  // ===========================================================================
  // CollabSessionState
  // ===========================================================================

  group('CollabSessionState', () {
    test('default state has null noteId and false isConnected', () {
      const state = CollabSessionState();
      expect(state.noteId, isNull);
      expect(state.isConnected, isFalse);
      expect(state.editorController, isNull);
    });

    test('copyWith preserves existing values when no arguments given', () {
      final controller = CrdtEditorController(crdt: CRDTText('site-test'));
      final state = CollabSessionState(
        noteId: 'note-1',
        isConnected: true,
        editorController: controller,
      );

      final copied = state.copyWith();
      expect(copied.noteId, 'note-1');
      expect(copied.isConnected, isTrue);
      expect(copied.editorController, controller);

      controller.dispose();
    });

    test('copyWith overrides specified fields', () {
      final controller = CrdtEditorController(crdt: CRDTText('site-test'));
      final state = CollabSessionState(
        noteId: 'note-1',
        isConnected: true,
        editorController: controller,
      );

      final copied = state.copyWith(isConnected: false);
      expect(copied.noteId, 'note-1');
      expect(copied.isConnected, isFalse);
      expect(copied.editorController, controller);

      controller.dispose();
    });
  });

  // ===========================================================================
  // CollabNotifier -- room lifecycle
  // ===========================================================================

  group('CollabNotifier room lifecycle', () {
    late MockWSClient mockClient;
    late ProviderContainer container;
    late CollabNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CollabNotifier.resetSiteIdCache();
      mockClient = MockWSClient();

      // Override wsClientProvider to use the mock.
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(StubApiClient()),
          wsClientProvider.overrideWith((ref) {
            return MockWSClientNotifier(mockClient);
          }),
        ],
      );

      notifier = container.read(collabProvider.notifier);
    });

    tearDown(() {
      container.dispose();
      mockClient.dispose();
    });

    test('initial state is disconnected with null noteId', () {
      final state = container.read(collabProvider);
      expect(state.noteId, isNull);
      expect(state.isConnected, isFalse);
      expect(state.editorController, isNull);
    });

    test('joinRoom creates editor controller and joins WS room', () async {
      await notifier.joinRoom('note-123');

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-123');
      expect(state.editorController, isNotNull);
      expect(mockClient.joinedRooms, ['note-123']);
    });

    test('joinRoom replaces previous session', () async {
      await notifier.joinRoom('note-first');
      expect(mockClient.joinedRooms, ['note-first']);

      await notifier.joinRoom('note-second');
      expect(mockClient.joinedRooms, ['note-first', 'note-second']);

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-second');
    });

    test('joinRoom with existing CRDT uses provided document', () async {
      final existingCrdt = CRDTText('site-existing');
      existingCrdt.localInsert(0, 'existing text');

      await notifier.joinRoom('note-crdt', existingCrdt: existingCrdt);

      final state = container.read(collabProvider);
      expect(state.editorController, isNotNull);
      // The CRDT document should contain the existing text.
      expect(state.editorController!.crdt.text, 'existing text');
    });

    test('leaveRoom clears state and leaves WS room', () async {
      await notifier.joinRoom('note-leave');
      expect(container.read(collabProvider).noteId, 'note-leave');

      notifier.leaveRoom();

      final state = container.read(collabProvider);
      expect(state.noteId, isNull);
      expect(state.isConnected, isFalse);
      expect(state.editorController, isNull);
      expect(mockClient.leftRooms, ['note-leave']);
    });

    test('leaveRoom without active session is a no-op', () async {
      // Should not throw.
      notifier.leaveRoom();

      final state = container.read(collabProvider);
      expect(state.noteId, isNull);
      expect(mockClient.leftRooms, isEmpty);
    });

    test('sendCursorPosition sends cursor via WS client', () async {
      await notifier.joinRoom('note-cursor');

      notifier.sendCursorPosition(42);

      expect(mockClient.sentCursors.length, 1);
      expect(mockClient.sentCursors[0], ('note-cursor', 42));
    });

    test('sendCursorPosition is no-op when not in a room', () {
      notifier.sendCursorPosition(10);
      expect(mockClient.sentCursors, isEmpty);
    });

    test('connection state updates propagate to session state', () async {
      await notifier.joinRoom('note-conn');
      expect(container.read(collabProvider).isConnected, isTrue);

      // Simulate disconnection.
      mockClient.simulateConnectionState(WSConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(collabProvider).isConnected, isFalse);

      // Simulate reconnection.
      mockClient.simulateConnectionState(WSConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(collabProvider).isConnected, isTrue);
    });

    test('dispose cleans up resources', () async {
      await notifier.joinRoom('note-dispose');

      // Dispose via the container (which calls notifier.dispose internally).
      // This should not throw.
      container.dispose();

      // After disposal, further operations should be no-ops.
      // Re-create container for subsequent tests.
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(StubApiClient()),
          wsClientProvider.overrideWith((ref) {
            return MockWSClientNotifier(mockClient);
          }),
        ],
      );
      notifier = container.read(collabProvider.notifier);

      // Verify the notifier is usable again (fresh state).
      final state = container.read(collabProvider);
      expect(state.noteId, isNull);
    });
  });

  // ===========================================================================
  // CollabNotifier -- outgoing operation batching
  // ===========================================================================

  group('CollabNotifier outgoing batching', () {
    late MockWSClient mockClient;
    late ProviderContainer container;
    late CollabNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CollabNotifier.resetSiteIdCache();
      mockClient = MockWSClient();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(StubApiClient()),
          wsClientProvider.overrideWith((ref) {
            return MockWSClientNotifier(mockClient);
          }),
        ],
      );
      notifier = container.read(collabProvider.notifier);
    });

    tearDown(() {
      container.dispose();
      mockClient.dispose();
    });

    test('local insert triggers batched send after debounce', () async {
      await notifier.joinRoom('note-batch');

      final editorController = container.read(collabProvider).editorController!;

      // Simulate a local edit by directly triggering the CRDT.
      editorController.textController.text = 'hello';
      await Future<void>.delayed(Duration.zero);

      // Wait for the 50ms debounce timer.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // An edit should have been sent.
      expect(mockClient.sentEdits.isNotEmpty, isTrue);
      final (noteId, payload) = mockClient.sentEdits.first;
      expect(noteId, 'note-batch');
      expect(payload, containsPair('ops', isA<List>()));
    });

    test('multiple rapid edits are batched into single send', () async {
      await notifier.joinRoom('note-batch-multi');

      final editorController = container.read(collabProvider).editorController!;

      // Rapidly insert multiple characters.
      editorController.textController.text = 'a';
      await Future<void>.delayed(Duration.zero);
      editorController.textController.text = 'ab';
      await Future<void>.delayed(Duration.zero);
      editorController.textController.text = 'abc';
      await Future<void>.delayed(Duration.zero);

      // Wait for debounce.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // All ops should be batched into a single send.
      expect(mockClient.sentEdits.length, 1);
      final (_, payload) = mockClient.sentEdits.first;
      final ops = payload['ops'] as List;
      // Should have multiple ops batched together.
      expect(ops.length, greaterThanOrEqualTo(1));
    });
  });

  // ===========================================================================
  // CollabNotifier -- incoming operation routing
  // ===========================================================================

  group('CollabNotifier incoming operations', () {
    late MockWSClient mockClient;
    late ProviderContainer container;
    late CollabNotifier notifier;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CollabNotifier.resetSiteIdCache();
      mockClient = MockWSClient();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          apiClientProvider.overrideWithValue(StubApiClient()),
          wsClientProvider.overrideWith((ref) {
            return MockWSClientNotifier(mockClient);
          }),
        ],
      );
      notifier = container.read(collabProvider.notifier);
    });

    tearDown(() {
      container.dispose();
      mockClient.dispose();
    });

    test('remote edit message updates editor controller', () async {
      await notifier.joinRoom('note-remote');

      final editorController = container.read(collabProvider).editorController!;

      // Create a remote node to insert.
      final remoteCrdt = CRDTText('site-remote');
      final remoteNodes = remoteCrdt.localInsert(0, 'remote');

      // Simulate receiving an edit message.
      mockClient.simulateMessage(
        WSMessage(WSMessageType.edit, {
          'room': 'note-remote',
          'ops': [
            {
              'inserts': remoteNodes.map((n) => n.toJson()).toList(),
            },
          ],
        }),
      );

      await Future<void>.delayed(Duration.zero);

      // The editor controller should have the remote text.
      expect(editorController.crdt.text, contains('remote'));
    });

    test('remote edit with delete operations', () async {
      await notifier.joinRoom('note-remote-del');

      final editorController = container.read(collabProvider).editorController!;

      // First, insert some text locally so there is something to delete.
      final localCrdt = editorController.crdt;
      final localNodes = localCrdt.localInsert(0, 'abc');
      expect(localCrdt.text, 'abc');

      // Simulate receiving a delete for node 'b' (index 1).
      final nodeIdToDelete = localNodes[1].id;

      mockClient.simulateMessage(
        WSMessage(WSMessageType.edit, {
          'room': 'note-remote-del',
          'ops': [
            {
              'deletes': [nodeIdToDelete],
            },
          ],
        }),
      );

      await Future<void>.delayed(Duration.zero);

      // 'b' should be deleted, leaving 'ac'.
      expect(editorController.crdt.text, 'ac');
    });

    test('cursor message is acknowledged without error', () async {
      await notifier.joinRoom('note-cursor-remote');

      // Should not throw.
      mockClient.simulateMessage(
        WSMessage(WSMessageType.cursor, {
          'room': 'note-cursor-remote',
          'position': 5,
        }),
      );

      await Future<void>.delayed(Duration.zero);

      // No crash, no state change to editor.
      final state = container.read(collabProvider);
      expect(state.noteId, 'note-cursor-remote');
    });

    test('edit message with no ops is handled gracefully', () async {
      await notifier.joinRoom('note-empty-ops');

      mockClient.simulateMessage(
        WSMessage(WSMessageType.edit, {
          'room': 'note-empty-ops',
          // No 'ops' key.
        }),
      );

      await Future<void>.delayed(Duration.zero);

      // Should not crash.
      final state = container.read(collabProvider);
      expect(state.noteId, 'note-empty-ops');
    });

    test('edit message with empty ops list is handled gracefully', () async {
      await notifier.joinRoom('note-no-ops');

      mockClient.simulateMessage(
        WSMessage(WSMessageType.edit, {
          'room': 'note-no-ops',
          'ops': <Map<String, dynamic>>[],
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-no-ops');
    });

    test('incoming edit before joinRoom is ignored', () async {
      // No room joined. Simulate a stray message.
      mockClient.simulateMessage(
        WSMessage(WSMessageType.edit, {
          'room': 'note-stray',
          'ops': [
            {'inserts': []},
          ],
        }),
      );

      await Future<void>.delayed(Duration.zero);

      // No crash.
      final state = container.read(collabProvider);
      expect(state.noteId, isNull);
    });
  });
}
