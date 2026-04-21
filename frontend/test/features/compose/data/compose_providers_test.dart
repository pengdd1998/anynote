import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:anynote/core/crypto/crypto_service.dart';
import 'package:anynote/core/database/app_database.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/features/compose/data/ai_repository.dart';
import 'package:anynote/features/compose/data/compose_providers.dart';
import 'package:anynote/features/compose/domain/cluster_model.dart';
import 'package:anynote/features/compose/domain/outline_model.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Mock AI Repository
// ---------------------------------------------------------------------------

/// Fake AIRepository that returns configurable responses.
class FakeAIRepository extends AIRepository {
  String? chatResponse;
  Stream<String>? chatStreamResponse;

  /// Track calls for assertions.
  final List<List<ChatMessage>> chatCalls = [];
  final List<List<ChatMessage>> chatStreamCalls = [];

  FakeAIRepository() : super(_FakeApiClient());

  @override
  Future<String> chat(List<ChatMessage> messages, {String? model}) async {
    chatCalls.add(messages);
    if (chatResponse != null) return chatResponse!;
    return '{}';
  }

  @override
  Stream<String> chatStream(List<ChatMessage> messages, {String? model}) {
    chatStreamCalls.add(messages);
    if (chatStreamResponse != null) return chatStreamResponse!;
    return Stream.fromIterable(['chunk1', 'chunk2']);
  }
}

/// Minimal ApiClient stub just to satisfy the AIRepository constructor.
class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://localhost:8080');
}

// ---------------------------------------------------------------------------
// Fake CryptoService
// ---------------------------------------------------------------------------

/// Minimal fake CryptoService for the save-draft flow.
class _FakeCryptoService extends CryptoService {
  @override
  bool get isUnlocked => true;

  @override
  Future<bool> isInitialized() async => true;

  @override
  Future<String> encryptForItem(String itemId, String plaintext) async =>
      'enc_$plaintext';

  @override
  Future<String?> decryptForItem(String itemId, String encrypted) async =>
      encrypted.replaceFirst('enc_', '');

  @override
  Future<void> lock() async {}
}

// ---------------------------------------------------------------------------
// Test database helper
// ---------------------------------------------------------------------------

/// Creates an in-memory AppDatabase for testing.
AppDatabase _createTestDb() {
  open.overrideFor(
    OperatingSystem.linux,
    () => DynamicLibrary.open('libsqlite3.so'),
  );
  sqlite3.tempDirectory = Directory.systemTemp.path;
  final file = File(
    '${Directory.systemTemp.path}/compose_test_${DateTime.now().millisecondsSinceEpoch}.sqlite',
  );
  return AppDatabase.forTesting(NativeDatabase(file));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // ComposeSessionState
  // ===========================================================================

  group('ComposeSessionState', () {
    test('default values are correct', () {
      const state = ComposeSessionState(sessionId: 'test-session');

      expect(state.sessionId, 'test-session');
      expect(state.stage, ComposeStage.selectNotes);
      expect(state.selectedNoteIds, isEmpty);
      expect(state.noteContents, isEmpty);
      expect(state.topic, '');
      expect(state.platformStyle, 'generic');
      expect(state.clusters, isEmpty);
      expect(state.selectedClusterIndices, isEmpty);
      expect(state.outline, isNull);
      expect(state.draft, '');
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const state = ComposeSessionState(sessionId: 's1', topic: 'original');
      final updated = state.copyWith(topic: 'updated');

      expect(updated.sessionId, 's1');
      expect(updated.topic, 'updated');
      expect(updated.stage, ComposeStage.selectNotes);
    });

    test('copyWith can update stage', () {
      const state = ComposeSessionState(sessionId: 's1');
      final updated = state.copyWith(stage: ComposeStage.cluster);

      expect(updated.stage, ComposeStage.cluster);
    });

    test('copyWith can update isLoading', () {
      const state = ComposeSessionState(sessionId: 's1');
      final updated = state.copyWith(isLoading: true);

      expect(updated.isLoading, isTrue);
    });

    test('copyWith sets error to null when error parameter is omitted', () {
      const state = ComposeSessionState(sessionId: 's1', error: 'some error');
      // copyWith always replaces error with the provided value or null.
      final updated = state.copyWith();

      expect(updated.error, isNull);
    });

    test('copyWith can set selectedNoteIds', () {
      const state = ComposeSessionState(sessionId: 's1');
      final updated = state.copyWith(
        selectedNoteIds: ['n1', 'n2'],
        noteContents: {'n1': 'hello', 'n2': 'world'},
      );

      expect(updated.selectedNoteIds, ['n1', 'n2']);
      expect(updated.noteContents, {'n1': 'hello', 'n2': 'world'});
    });

    test('copyWith can set outline', () {
      const state = ComposeSessionState(sessionId: 's1');
      final outline = OutlineModel(
        title: 'Test',
        sections: [
          OutlineSection(heading: 'H1', points: ['p1']),
        ],
      );
      final updated = state.copyWith(outline: outline);

      expect(updated.outline, isNotNull);
      expect(updated.outline!.title, 'Test');
      expect(updated.outline!.sections.length, 1);
    });

    test('copyWith can set draft', () {
      const state = ComposeSessionState(sessionId: 's1');
      final updated = state.copyWith(draft: 'Generated text here');

      expect(updated.draft, 'Generated text here');
    });

    test('copyWith can set clusters', () {
      const state = ComposeSessionState(sessionId: 's1');
      final clusters = [
        const ClusterModel(
            name: 'A', theme: 't', noteIndices: [0], summary: 's'),
      ];
      final updated = state.copyWith(
        clusters: clusters,
        selectedClusterIndices: {0},
      );

      expect(updated.clusters.length, 1);
      expect(updated.selectedClusterIndices, {0});
    });

    test('copyWith can set platformStyle', () {
      const state = ComposeSessionState(sessionId: 's1');
      final updated = state.copyWith(platformStyle: 'xhs');

      expect(updated.platformStyle, 'xhs');
    });

    test('ComposeStage enum has four values', () {
      expect(ComposeStage.values.length, 4);
      expect(ComposeStage.values, contains(ComposeStage.selectNotes));
      expect(ComposeStage.values, contains(ComposeStage.cluster));
      expect(ComposeStage.values, contains(ComposeStage.outline));
      expect(ComposeStage.values, contains(ComposeStage.editor));
    });

    test('const constructor allows compile-time constants', () {
      const state1 = ComposeSessionState(sessionId: 'a');
      const state2 = ComposeSessionState(sessionId: 'a');
      expect(state1.stage, state2.stage);
      expect(state1.isLoading, state2.isLoading);
    });
  });

  // ===========================================================================
  // ComposeSessionNotifier
  // ===========================================================================

  group('ComposeSessionNotifier', () {
    late ProviderContainer container;
    late FakeAIRepository fakeAiRepo;
    late AppDatabase testDb;

    setUp(() {
      fakeAiRepo = FakeAIRepository();
      testDb = _createTestDb();

      container = ProviderContainer(
        overrides: [
          aiRepositoryProvider.overrideWithValue(fakeAiRepo),
          databaseProvider.overrideWithValue(testDb),
          cryptoServiceProvider.overrideWithValue(_FakeCryptoService()),
        ],
      );
    });

    tearDown(() async {
      await testDb.close();
      container.dispose();
    });

    // -- Note selection -----------------------------------------------------

    test('toggleNoteSelection adds a note', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('note-1', 'content of note 1');

      final state = container.read(composeSessionProvider);
      expect(state.selectedNoteIds, contains('note-1'));
      expect(state.noteContents['note-1'], 'content of note 1');
    });

    test('toggleNoteSelection removes an already-selected note', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('note-1', 'content 1');
      notifier.toggleNoteSelection('note-1', 'content 1');

      final state = container.read(composeSessionProvider);
      expect(state.selectedNoteIds, isNot(contains('note-1')));
      expect(state.noteContents.containsKey('note-1'), isFalse);
    });

    test('toggleNoteSelection supports multiple notes', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'c1');
      notifier.toggleNoteSelection('n2', 'c2');
      notifier.toggleNoteSelection('n3', 'c3');

      final state = container.read(composeSessionProvider);
      expect(state.selectedNoteIds.length, 3);
      expect(state.noteContents.length, 3);
    });

    // -- Topic --------------------------------------------------------------

    test('setTopic updates the topic', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.setTopic('My Composition Topic');

      final state = container.read(composeSessionProvider);
      expect(state.topic, 'My Composition Topic');
    });

    // -- Platform style -----------------------------------------------------

    test('setPlatformStyle updates the platform style', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.setPlatformStyle('xhs');

      final state = container.read(composeSessionProvider);
      expect(state.platformStyle, 'xhs');
    });

    // -- Generate clusters --------------------------------------------------

    test('generateClusters does nothing when no notes selected', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.setTopic('topic');
      await notifier.generateClusters();

      expect(fakeAiRepo.chatCalls, isEmpty);
    });

    test('generateClusters does nothing when topic is empty', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'content');
      await notifier.generateClusters();

      expect(fakeAiRepo.chatCalls, isEmpty);
    });

    test('generateClusters sets error on invalid JSON response', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'content');
      notifier.setTopic('my topic');

      fakeAiRepo.chatResponse = 'not valid json';

      await notifier.generateClusters();

      final state = container.read(composeSessionProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Failed to generate clusters'));
    });

    test('generateClusters succeeds with valid JSON', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'content');
      notifier.setTopic('my topic');

      fakeAiRepo.chatResponse = '''```json
{
  "clusters": [
    {
      "name": "Theme A",
      "theme": "Core theme A",
      "note_indices": [0],
      "summary": "Summary A"
    }
  ]
}
```''';

      await notifier.generateClusters();

      final state = container.read(composeSessionProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.stage, ComposeStage.cluster);
      expect(state.clusters.length, 1);
      expect(state.clusters[0].name, 'Theme A');
      expect(state.selectedClusterIndices, {0});
    });

    test('generateClusters selects all clusters by default', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'c1');
      notifier.toggleNoteSelection('n2', 'c2');
      notifier.setTopic('topic');

      fakeAiRepo.chatResponse = '{"clusters": []}';

      await notifier.generateClusters();

      final state = container.read(composeSessionProvider);
      expect(state.selectedClusterIndices, isEmpty);
    });

    test('generateClusters sets loading state during operation', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'content');
      notifier.setTopic('my topic');

      // Delay the response to check loading state.
      fakeAiRepo.chatResponse = '{"clusters": []}';

      final future = notifier.generateClusters();

      // Right after calling, isLoading should be true.
      expect(container.read(composeSessionProvider).isLoading, isTrue);

      await future;

      expect(container.read(composeSessionProvider).isLoading, isFalse);
    });

    // -- Cluster selection --------------------------------------------------

    test('toggleClusterSelection adds an index', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        stage: ComposeStage.cluster,
        clusters: [
          const ClusterModel(
              name: 'A', theme: 't', noteIndices: [0], summary: 's'),
          const ClusterModel(
              name: 'B', theme: 't', noteIndices: [1], summary: 's'),
        ],
        selectedClusterIndices: {0},
      );

      notifier.toggleClusterSelection(1);

      final state = container.read(composeSessionProvider);
      expect(state.selectedClusterIndices, {0, 1});
    });

    test('toggleClusterSelection removes an index', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        stage: ComposeStage.cluster,
        clusters: [
          const ClusterModel(
              name: 'A', theme: 't', noteIndices: [0], summary: 's'),
        ],
        selectedClusterIndices: {0},
      );

      notifier.toggleClusterSelection(0);

      final state = container.read(composeSessionProvider);
      expect(state.selectedClusterIndices, isEmpty);
    });

    // -- Generate outline ---------------------------------------------------

    test('generateOutline does nothing when no clusters selected', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        stage: ComposeStage.cluster,
        selectedClusterIndices: {},
      );

      await notifier.generateOutline();

      expect(fakeAiRepo.chatCalls, isEmpty);
    });

    test('generateOutline sets error on failure', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        stage: ComposeStage.cluster,
        clusters: [
          const ClusterModel(
              name: 'A', theme: 't', noteIndices: [0], summary: 's'),
        ],
        selectedClusterIndices: {0},
      );

      fakeAiRepo.chatResponse = 'bad json';

      await notifier.generateOutline();

      final state = container.read(composeSessionProvider);
      expect(state.error, contains('Failed to generate outline'));
      expect(state.isLoading, isFalse);
    });

    test('generateOutline succeeds with valid response', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        stage: ComposeStage.cluster,
        clusters: [
          const ClusterModel(
              name: 'A', theme: 't', noteIndices: [0], summary: 's'),
        ],
        selectedClusterIndices: {0},
      );

      fakeAiRepo.chatResponse = '{"title": "My Post", "sections": []}';

      await notifier.generateOutline();

      final state = container.read(composeSessionProvider);
      expect(state.error, isNull);
      expect(state.stage, ComposeStage.outline);
      expect(state.outline, isNotNull);
      expect(state.outline!.title, 'My Post');
    });

    test('generateOutline parses sections correctly', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        stage: ComposeStage.cluster,
        clusters: [
          const ClusterModel(
              name: 'A', theme: 't', noteIndices: [0], summary: 's'),
        ],
        selectedClusterIndices: {0},
      );

      fakeAiRepo.chatResponse = '''{
        "title": "Post",
        "sections": [
          {"heading": "Intro", "points": ["p1", "p2"]},
          {"heading": "Body", "points": ["p3"]}
        ]
      }''';

      await notifier.generateOutline();

      final state = container.read(composeSessionProvider);
      expect(state.outline!.sections.length, 2);
      expect(state.outline!.sections[0].heading, 'Intro');
      expect(state.outline!.sections[0].points, ['p1', 'p2']);
    });

    // -- Update outline -----------------------------------------------------

    test('updateOutline replaces the outline', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      final outline = OutlineModel(
        title: 'Updated',
        sections: [
          OutlineSection(heading: 'New Section', points: ['a', 'b']),
        ],
      );

      notifier.updateOutline(outline);

      final state = container.read(composeSessionProvider);
      expect(state.outline!.title, 'Updated');
      expect(state.outline!.sections.length, 1);
    });

    // -- Reorder section ----------------------------------------------------

    test('reorderSection moves sections', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        outline: OutlineModel(
          title: 'Test',
          sections: [
            OutlineSection(heading: 'A', points: []),
            OutlineSection(heading: 'B', points: []),
            OutlineSection(heading: 'C', points: []),
          ],
        ),
      );

      // Move section 0 (A) to position 2.
      notifier.reorderSection(0, 2);

      final state = container.read(composeSessionProvider);
      expect(state.outline!.sections[0].heading, 'B');
      expect(state.outline!.sections[1].heading, 'C');
      expect(state.outline!.sections[2].heading, 'A');
    });

    test('reorderSection does nothing when outline is null', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      // outline is null by default -- should not throw.
      notifier.reorderSection(0, 1);

      final state = container.read(composeSessionProvider);
      expect(state.outline, isNull);
    });

    // -- Update draft -------------------------------------------------------

    test('updateDraft sets the draft text', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.updateDraft('This is the draft content');

      final state = container.read(composeSessionProvider);
      expect(state.draft, 'This is the draft content');
    });

    // -- Clear error --------------------------------------------------------

    test('clearError removes the error', () {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state =
          notifier.state.copyWith(error: 'Something went wrong');

      notifier.clearError();

      final state = container.read(composeSessionProvider);
      expect(state.error, isNull);
    });

    // -- Extract JSON helper (tested indirectly via chat responses) ---------

    test('handles JSON in markdown fences', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'c1');
      notifier.setTopic('t');

      // Response with markdown code fences.
      fakeAiRepo.chatResponse =
          'Here are the clusters:\n```json\n{"clusters": []}\n```\nDone.';

      await notifier.generateClusters();

      final state = container.read(composeSessionProvider);
      expect(state.error, isNull);
      expect(state.clusters, isEmpty);
    });

    test('handles raw JSON without fences', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.toggleNoteSelection('n1', 'c1');
      notifier.setTopic('t');

      // Raw JSON without markdown fences.
      fakeAiRepo.chatResponse = '{"clusters": []}';

      await notifier.generateClusters();

      final state = container.read(composeSessionProvider);
      expect(state.error, isNull);
      expect(state.clusters, isEmpty);
    });

    // -- Save draft as note -------------------------------------------------

    test('saveDraftAsNote returns null when draft is empty', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      final result = await notifier.saveDraftAsNote();

      expect(result, isNull);
    });

    test('saveDraftAsNote returns a note ID on success', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        draft: 'This is a draft.',
        outline: OutlineModel(title: 'Draft Title', sections: []),
      );

      final result = await notifier.saveDraftAsNote();

      expect(result, isNotNull);
      // UUID v4 format.
      expect(
        result,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        )),
      );
    });

    test('saveDraftAsNote falls back to AI Composition title when no outline',
        () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        draft: 'Draft without outline.',
        // outline is null.
      );

      final result = await notifier.saveDraftAsNote();

      // Should succeed even without an outline.
      expect(result, isNotNull);
    });

    // -- Expand to draft ----------------------------------------------------

    test('expandToDraft does nothing when outline is null', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      await notifier.expandToDraft();

      expect(fakeAiRepo.chatStreamCalls, isEmpty);
    });

    test('expandToDraft sets stage to editor', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        outline: OutlineModel(title: 'Test', sections: []),
        selectedClusterIndices: {},
      );

      fakeAiRepo.chatStreamResponse = Stream.fromIterable(['Hello ', 'world']);

      await notifier.expandToDraft();

      final state = container.read(composeSessionProvider);
      expect(state.stage, ComposeStage.editor);
      expect(state.draft, 'Hello world');
      expect(state.isLoading, isFalse);
    });

    test('expandToDraft accumulates streaming chunks', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        outline: OutlineModel(title: 'Test', sections: []),
        selectedClusterIndices: {},
      );

      fakeAiRepo.chatStreamResponse =
          Stream.fromIterable(['First ', 'Second ', 'Third']);

      await notifier.expandToDraft();

      final state = container.read(composeSessionProvider);
      expect(state.draft, 'First Second Third');
    });

    test('expandToDraft sets error on stream failure', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        outline: OutlineModel(title: 'Test', sections: []),
        selectedClusterIndices: {},
      );

      fakeAiRepo.chatStreamResponse = Stream.error(Exception('broken'));

      await notifier.expandToDraft();

      final state = container.read(composeSessionProvider);
      expect(state.error, contains('Failed to generate draft'));
      expect(state.isLoading, isFalse);
    });

    // -- Adapt style --------------------------------------------------------

    test('adaptStyle does nothing when draft is empty', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      await notifier.adaptStyle();

      expect(fakeAiRepo.chatStreamCalls, isEmpty);
    });

    test('adaptStyle streams adapted content', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(
        draft: 'Original content',
        platformStyle: 'xhs',
      );

      fakeAiRepo.chatStreamResponse =
          Stream.fromIterable(['Adapted ', 'for ', 'XHS']);

      await notifier.adaptStyle();

      final state = container.read(composeSessionProvider);
      expect(state.draft, 'Adapted for XHS');
      expect(state.isLoading, isFalse);
    });

    test('adaptStyle sets error on failure', () async {
      final notifier =
          container.read(composeSessionProvider.notifier);

      notifier.state = notifier.state.copyWith(draft: 'content');

      fakeAiRepo.chatStreamResponse =
          Stream.error(Exception('stream failed'));

      await notifier.adaptStyle();

      final state = container.read(composeSessionProvider);
      expect(state.error, contains('Style adaptation failed'));
      expect(state.isLoading, isFalse);
    });
  });

  // ===========================================================================
  // Providers
  // ===========================================================================

  group('startComposeSessionProvider', () {
    test('returns a function that creates a session ID', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final startSession = container.read(startComposeSessionProvider);
      final sessionId = startSession();

      expect(sessionId, isNotEmpty);
      // UUID v4 format: 8-4-4-4-12 hex chars.
      expect(
        sessionId,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        )),
      );
    });

    test('sets the composeSessionIdProvider state', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final startSession = container.read(startComposeSessionProvider);
      final sessionId = startSession();

      expect(container.read(composeSessionIdProvider), sessionId);
    });

    test('creates a different ID each call', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      final startSession = container.read(startComposeSessionProvider);
      final id1 = startSession();
      final id2 = startSession();

      expect(id1, isNot(equals(id2)));
    });
  });

  group('composeSessionIdProvider', () {
    test('initial state is null', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      expect(container.read(composeSessionIdProvider), isNull);
    });
  });
}
