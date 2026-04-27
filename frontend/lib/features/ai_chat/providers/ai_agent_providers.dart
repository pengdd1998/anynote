import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';

/// State for an AI agent action execution.
class AgentState {
  final bool isLoading;
  final Map<String, dynamic>? result;
  final String? error;

  const AgentState({this.isLoading = false, this.result, this.error});

  AgentState copyWith({
    bool? isLoading,
    Map<String, dynamic>? result,
    String? error,
  }) {
    return AgentState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }

  bool get isIdle => !isLoading && result == null && error == null;
}

/// Notifier that manages AI agent action execution.
class AgentNotifier extends StateNotifier<AgentState> {
  final Ref _ref;

  AgentNotifier(this._ref) : super(const AgentState());

  /// Execute an AI agent action.
  Future<void> execute({
    required String action,
    List<String>? noteIds,
    Map<String, dynamic>? context,
    Map<String, dynamic>? parameters,
  }) async {
    state = const AgentState(isLoading: true);

    try {
      final api = _ref.read(apiClientProvider);
      final resp = await api.executeAgentAction({
        'action': action,
        if (noteIds != null) 'note_ids': noteIds,
        if (context != null) 'context': context,
        if (parameters != null) 'parameters': parameters,
      });
      state = AgentState(result: resp);
    } catch (e) {
      state = AgentState(error: e.toString());
    }
  }

  /// Reset to idle state.
  void reset() {
    state = const AgentState();
  }
}

/// Provider for AI agent actions.
final aiAgentProvider = StateNotifierProvider<AgentNotifier, AgentState>((ref) {
  return AgentNotifier(ref);
});
