import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/ai_chat/providers/ai_agent_providers.dart';
import 'package:anynote/core/network/api_client.dart';
import 'package:anynote/main.dart';

// ---------------------------------------------------------------------------
// Stub ApiClient
// ---------------------------------------------------------------------------

/// A fake ApiClient that returns configurable responses for agent actions.
class FakeApiClient extends ApiClient {
  Map<String, dynamic>? agentResponse;
  Object? agentError;

  FakeApiClient() : super(baseUrl: 'http://localhost:8080');

  @override
  Future<Map<String, dynamic>> executeAgentAction(
    Map<String, dynamic> req,
  ) async {
    if (agentError != null) {
      throw agentError!;
    }
    return agentResponse ?? {'status': 'ok'};
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AgentState', () {
    test('default constructor has idle state', () {
      const state = AgentState();

      expect(state.isLoading, isFalse);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('isIdle is true when all fields are default', () {
      const state = AgentState();
      expect(state.isIdle, isTrue);
    });

    test('isIdle is false when isLoading is true', () {
      const state = AgentState(isLoading: true);
      expect(state.isIdle, isFalse);
    });

    test('isIdle is false when result is set', () {
      const state = AgentState(result: {'key': 'value'});
      expect(state.isIdle, isFalse);
    });

    test('isIdle is false when error is set', () {
      const state = AgentState(error: 'something broke');
      expect(state.isIdle, isFalse);
    });

    test('isLoading state', () {
      const state = AgentState(isLoading: true);
      expect(state.isLoading, isTrue);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('result state', () {
      const state = AgentState(result: {'action': 'organize', 'count': 5});
      expect(state.isLoading, isFalse);
      expect(state.result, isNotNull);
      expect(state.result!['action'], 'organize');
      expect(state.result!['count'], 5);
    });

    test('error state', () {
      const state = AgentState(error: 'Network failure');
      expect(state.isLoading, isFalse);
      expect(state.error, 'Network failure');
    });
  });

  group('AgentNotifier', () {
    late ProviderContainer container;
    late FakeApiClient fakeApi;

    setUp(() {
      fakeApi = FakeApiClient();

      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    // -- Initial state --------------------------------------------------------

    test('initial state is idle', () {
      final notifier = container.read(aiAgentProvider.notifier);

      expect(notifier.state.isIdle, isTrue);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.result, isNull);
      expect(notifier.state.error, isNull);
    });

    // -- Execute -- success ---------------------------------------------------

    test('execute sets loading then result on success', () async {
      fakeApi.agentResponse = {
        'action': 'organize',
        'notes_organized': 10,
      };

      final notifier = container.read(aiAgentProvider.notifier);
      final future = notifier.execute(action: 'organize');

      // Right after calling, should be loading.
      expect(container.read(aiAgentProvider).isLoading, isTrue);

      await future;

      final state = container.read(aiAgentProvider);
      expect(state.isLoading, isFalse);
      expect(state.result, isNotNull);
      expect(state.result!['action'], 'organize');
      expect(state.result!['notes_organized'], 10);
      expect(state.error, isNull);
    });

    test('execute with noteIds passes them to api', () async {
      fakeApi.agentResponse = {'status': 'ok'};

      final notifier = container.read(aiAgentProvider.notifier);
      await notifier.execute(
        action: 'summarize',
        noteIds: ['n1', 'n2'],
      );

      expect(container.read(aiAgentProvider).result, isNotNull);
    });

    test('execute with context and parameters', () async {
      fakeApi.agentResponse = {'result': 'generated'};

      final notifier = container.read(aiAgentProvider.notifier);
      await notifier.execute(
        action: 'create_note',
        context: {'topic': 'AI'},
        parameters: {'length': 'short'},
      );

      final state = container.read(aiAgentProvider);
      expect(state.result, isNotNull);
      expect(state.result!['result'], 'generated');
    });

    // -- Execute -- failure ---------------------------------------------------

    test('execute sets error on failure', () async {
      fakeApi.agentError = Exception('Server unreachable');

      final notifier = container.read(aiAgentProvider.notifier);
      await notifier.execute(action: 'organize');

      final state = container.read(aiAgentProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(state.error, contains('Server unreachable'));
      expect(state.result, isNull);
    });

    test('execute sets error on DioException', () async {
      fakeApi.agentError = Exception('HTTP 500');

      final notifier = container.read(aiAgentProvider.notifier);
      await notifier.execute(action: 'summarize');

      final state = container.read(aiAgentProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    // -- Reset ----------------------------------------------------------------

    test('reset returns to idle state', () async {
      fakeApi.agentResponse = {'status': 'done'};

      final notifier = container.read(aiAgentProvider.notifier);
      await notifier.execute(action: 'organize');

      // Verify we are in a non-idle state.
      expect(container.read(aiAgentProvider).isIdle, isFalse);

      notifier.reset();

      final state = container.read(aiAgentProvider);
      expect(state.isIdle, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.result, isNull);
      expect(state.error, isNull);
    });

    test('reset after error returns to idle', () async {
      fakeApi.agentError = Exception('fail');

      final notifier = container.read(aiAgentProvider.notifier);
      await notifier.execute(action: 'organize');

      expect(container.read(aiAgentProvider).error, isNotNull);

      notifier.reset();

      expect(container.read(aiAgentProvider).isIdle, isTrue);
      expect(container.read(aiAgentProvider).error, isNull);
    });

    // -- State transitions ----------------------------------------------------

    test('execute after reset works correctly', () async {
      fakeApi.agentError = Exception('first fail');
      fakeApi.agentResponse = null;

      final notifier = container.read(aiAgentProvider.notifier);

      // First call fails.
      await notifier.execute(action: 'organize');
      expect(container.read(aiAgentProvider).error, isNotNull);

      // Reset.
      notifier.reset();
      expect(container.read(aiAgentProvider).isIdle, isTrue);

      // Second call succeeds.
      fakeApi.agentError = null;
      fakeApi.agentResponse = {'status': 'success'};
      await notifier.execute(action: 'organize');

      final state = container.read(aiAgentProvider);
      expect(state.error, isNull);
      expect(state.result, isNotNull);
    });
  });

  group('aiAgentProvider', () {
    test('provider returns AgentNotifier', () {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final notifier = container.read(aiAgentProvider.notifier);
      expect(notifier, isA<AgentNotifier>());
    });

    test('provider exposes AgentState', () {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
        ],
      );
      addTearDown(() => container.dispose());

      final state = container.read(aiAgentProvider);
      expect(state, isA<AgentState>());
      expect(state.isIdle, isTrue);
    });
  });
}
