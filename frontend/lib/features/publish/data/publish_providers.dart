import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../main.dart';

// ── Publish History ──────────────────────────────────

/// Manages the publish history list.
class PublishHistoryNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final api = ref.read(apiClientProvider);
    return api.publishHistory();
  }

  /// Refresh the publish history from the server.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final publishHistoryProvider =
    AsyncNotifierProvider<PublishHistoryNotifier, List<Map<String, dynamic>>>(
  PublishHistoryNotifier.new,
);

// ── Connected Platforms for Publish ──────────────────

/// Fetches connected platforms for the publish screen.
/// Reuses the same API endpoint as settings but filters to only connected ones.
class ConnectedPlatformsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final api = ref.read(apiClientProvider);
    final all = await api.listPlatforms();
    // Filter to only show connected platforms
    return all.where((p) => p['connected'] == true).toList();
  }

  /// Refresh the connected platforms list.
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final connectedPlatformsProvider =
    AsyncNotifierProvider<ConnectedPlatformsNotifier,
        List<Map<String, dynamic>>>(
  ConnectedPlatformsNotifier.new,
);

// ── Publish Action ───────────────────────────────────

/// State for tracking publish operation progress.
class PublishActionState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? result;

  const PublishActionState({
    this.isLoading = false,
    this.error,
    this.result,
  });

  PublishActionState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? result,
  }) {
    return PublishActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      result: result ?? this.result,
    );
  }
}

/// Manages publish action state (loading, error, result).
class PublishActionNotifier extends StateNotifier<PublishActionState> {
  final ApiClient _api;

  PublishActionNotifier(this._api) : super(const PublishActionState());

  /// Execute a publish action.
  Future<void> publish({
    required String platform,
    required String title,
    required String content,
    List<String> tags = const [],
    String? contentItemId,
  }) async {
    state = const PublishActionState(isLoading: true);

    try {
      final req = <String, dynamic>{
        'platform': platform,
        'title': title,
        'content': content,
        'tags': tags,
      };
      if (contentItemId != null) {
        req['content_item_id'] = contentItemId;
      }

      final result = await _api.publish(req);
      state = PublishActionState(result: result);
    } on DioException catch (e) {
      state = PublishActionState(
        error: e.message ?? 'Network error occurred',
      );
    } catch (e) {
      state = PublishActionState(error: e.toString());
    }
  }

  /// Reset the publish action state.
  void reset() {
    state = const PublishActionState();
  }
}

final publishActionProvider =
    StateNotifierProvider<PublishActionNotifier, PublishActionState>(
  (ref) {
    final api = ref.read(apiClientProvider);
    return PublishActionNotifier(api);
  },
);

// ── Publish Detail ───────────────────────────────────

/// Fetches a single publish log entry by ID.
final publishDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  return api.getPublish(id);
});
