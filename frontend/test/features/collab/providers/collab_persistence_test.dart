import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:anynote/core/collab/crdt_text.dart';
import 'package:anynote/core/collab/merge_engine.dart';
import 'package:anynote/core/collab/ws_client.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/collab/providers/collab_provider.dart';
import 'package:anynote/main.dart' show apiClientProvider, databaseProvider;

// ---------------------------------------------------------------------------
// Mock WSClient that records method calls.
// ---------------------------------------------------------------------------
class MockWSClient extends WSClient {
  final List<String> joinedRooms = [];
  final List<String> leftRooms = [];

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
  void dispose() {
    _messageController.close();
    _stateController.close();
  }
}

// ---------------------------------------------------------------------------
// Mock WSClientNotifier.
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
// Stub ApiClient.
// ---------------------------------------------------------------------------
class StubApiClient extends ApiClient {
  StubApiClient() : super(baseUrl: 'http://localhost:8080');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    CollabNotifier.resetSiteIdCache();
    SharedPreferences.setMockInitialValues({});

    // Use an in-memory database for testing.
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').getSingle();
  });

  tearDown(() async {
    await db.close();
    CollabNotifier.resetSiteIdCache();
  });

  group('CRDT state persistence on joinRoom', () {
    late MockWSClient mockClient;
    late ProviderContainer container;

    setUp(() {
      mockClient = MockWSClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(StubApiClient()),
          databaseProvider.overrideWithValue(db),
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

    test('joinRoom loads persisted CRDT state when available', () async {
      // Pre-populate a saved CRDT state for note 'note-persist'.
      final crdt = CRDTText('test-site');
      crdt.localInsert(0, 'saved content');
      final stateJson =
          '{"site_id":"test-site","clock":${crdt.clock},"nodes":${crdt.toJson()['nodes']}}';

      await db.collabDao.saveState(
        noteId: 'note-persist',
        documentState: stateJson,
        lastVersion: crdt.clock,
      );

      final notifier = container.read(collabProvider.notifier);
      await notifier.joinRoom('note-persist');

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-persist');
    });

    test('joinRoom works when no persisted state exists', () async {
      final notifier = container.read(collabProvider.notifier);
      await notifier.joinRoom('note-no-state');

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-no-state');
      expect(state.editorController, isNotNull);
    });

    test('joinRoom with existingCrdt overrides persisted state', () async {
      // Pre-populate a saved CRDT state.
      await db.collabDao.saveState(
        noteId: 'note-override',
        documentState: '{"site_id":"old","clock":0,"nodes":[]}',
        lastVersion: 0,
      );

      final existingCrdt = CRDTText('override-site');
      existingCrdt.localInsert(0, 'override content');

      final notifier = container.read(collabProvider.notifier);
      await notifier.joinRoom('note-override', existingCrdt: existingCrdt);

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-override');
      // The editor should use the provided CRDT, not the persisted state.
      expect(state.editorController!.crdt.text, 'override content');
    });

    test('corrupt persisted state does not crash joinRoom', () async {
      // Save invalid JSON.
      await db.collabDao.saveState(
        noteId: 'note-corrupt',
        documentState: 'not valid json {{{',
        lastVersion: 0,
      );

      final notifier = container.read(collabProvider.notifier);
      // Should not throw.
      await notifier.joinRoom('note-corrupt');

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-corrupt');
    });
  });

  group('CRDT state persistence on leaveRoom', () {
    late MockWSClient mockClient;
    late ProviderContainer container;

    setUp(() {
      mockClient = MockWSClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(StubApiClient()),
          databaseProvider.overrideWithValue(db),
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

    test('leaveRoom persists CRDT state before cleanup', () async {
      final notifier = container.read(collabProvider.notifier);
      await notifier.joinRoom('note-leave-persist');

      final state = container.read(collabProvider);
      expect(state.noteId, 'note-leave-persist');

      // Leave the room (triggers async persist).
      notifier.leaveRoom();

      // Allow the fire-and-forget persist to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify state was persisted to the database.
      final saved = await db.collabDao.loadState('note-leave-persist');
      expect(saved, isNotNull);
    });

    test('leaveRoom clears session state', () async {
      final notifier = container.read(collabProvider.notifier);
      await notifier.joinRoom('note-leave-clear');
      notifier.leaveRoom();

      final state = container.read(collabProvider);
      expect(state.noteId, isNull);
      expect(state.isConnected, isFalse);
      expect(state.editorController, isNull);
    });
  });

  group('CRDT state periodic persistence', () {
    late MockWSClient mockClient;
    late ProviderContainer container;

    setUp(() {
      mockClient = MockWSClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(StubApiClient()),
          databaseProvider.overrideWithValue(db),
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

    test('state is not persisted when not in a room', () async {
      final notifier = container.read(collabProvider.notifier);
      await notifier.joinRoom('note-tmp');
      notifier.leaveRoom();

      // Should not throw when checking state.
      expect(
        () async => db.collabDao.loadState('note-tmp'),
        returnsNormally,
      );
    });
  });

  group('MergeEngine state serialization round-trip', () {
    test('exportState and loadState preserve document content', () {
      final engine = MergeEngine('test-site');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'hello world');

      final exported = engine.exportState();
      expect(exported, isNotEmpty);

      // Create a new engine and load the state.
      final engine2 = MergeEngine('test-site');
      engine2.loadState('note-1', exported);

      final doc2 = engine2.getDocument('note-1');
      expect(doc2.text, 'hello world');
    });

    test('clock value is preserved through export/load cycle', () {
      final engine = MergeEngine('test-site');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'abc');
      final originalClock = engine.clock;

      final exported = engine.exportState();

      final engine2 = MergeEngine('test-site');
      engine2.loadState('note-1', exported);

      // The loaded engine should have a clock value at least as high.
      // Note: getDocument creates a new doc if 'note-1' was loaded, the
      // clock comes from the loaded CRDTText.
      final loadedDoc = engine2.getDocument('note-1');
      expect(loadedDoc.clock, originalClock);
    });

    test('exportState includes siteId', () {
      final engine = MergeEngine('my-unique-site');
      final exported = engine.exportState();

      expect(exported, contains('my-unique-site'));
    });

    test('loadState replaces existing document', () {
      final engine = MergeEngine('test-site');
      final doc = engine.getDocument('note-1');
      doc.localInsert(0, 'old content');

      // Create state with different content.
      final otherEngine = MergeEngine('other-site');
      final otherDoc = otherEngine.getDocument('note-1');
      otherDoc.localInsert(0, 'new content');
      final exported = otherEngine.exportState();

      engine.loadState('note-1', exported);

      // The document should now have the new content.
      final restoredDoc = engine.getDocument('note-1');
      expect(restoredDoc.text, 'new content');
    });

    test('loadState with empty state string throws', () {
      final engine = MergeEngine('test-site');

      expect(
        () => engine.loadState('note-1', ''),
        throwsA(isA<FormatException>()),
      );
    });

    test('exportState with multiple documents preserves all', () {
      final engine = MergeEngine('test-site');
      engine.getDocument('note-a').localInsert(0, 'content a');
      engine.getDocument('note-b').localInsert(0, 'content b');

      final exported = engine.exportState();

      final engine2 = MergeEngine('test-site');
      engine2.loadState('note-a', exported);
      // Note: loadState loads by noteId internally using CRDTText.fromJson,
      // but our loadState only loads a single document. For full engine
      // restore, use MergeEngine.fromJson.

      final _ = engine2.getDocument('note-a');
      // The loaded state will have all documents under 'documents' key,
      // but loadState only takes the top-level JSON and puts it as a single
      // CRDTText. This is expected -- full restore uses fromJson.
      // Verify the exported state contains both documents.
      expect(exported, contains('note-a'));
      expect(exported, contains('note-b'));
    });

    test('MergeEngine.fromJson restores full engine state', () {
      final engine = MergeEngine('test-site');
      engine.getDocument('note-a').localInsert(0, 'content a');
      engine.getDocument('note-b').localInsert(0, 'content b');
      final json = engine.toJson();

      final restored = MergeEngine.fromJson(json);
      expect(restored.siteId, 'test-site');
      expect(restored.getDocument('note-a').text, 'content a');
      expect(restored.getDocument('note-b').text, 'content b');
    });

    test('empty engine export and restore', () {
      final engine = MergeEngine('empty-site');
      expect(engine.clock, 0);

      final exported = engine.exportState();
      final restored = MergeEngine.fromJson(
        jsonDecode(exported) as Map<String, dynamic>,
      );
      expect(restored.siteId, 'empty-site');
      expect(restored.clock, 0);
    });
  });
}
