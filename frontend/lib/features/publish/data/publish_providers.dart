import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/error/error.dart';
import '../../../core/network/api_client.dart';
import '../../../main.dart';
import '../domain/publish_rules.dart';

// ── Publish History ──────────────────────────────────

/// Manages the publish history list.
class PublishHistoryNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
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

final connectedPlatformsProvider = AsyncNotifierProvider<
    ConnectedPlatformsNotifier, List<Map<String, dynamic>>>(
  ConnectedPlatformsNotifier.new,
);

// ── Publish Action ───────────────────────────────────

/// State for tracking publish operation progress.
class PublishActionState {
  final bool isLoading;
  final String? error;

  /// Why the server rejected the post, field by field. Empty unless
  /// [error] is set and the server named specific problems.
  final List<PublishProblem> problems;

  /// Advice from the server that did not stop the publish.
  final List<PublishProblem> warnings;
  final Map<String, dynamic>? result;

  const PublishActionState({
    this.isLoading = false,
    this.error,
    this.problems = const [],
    this.warnings = const [],
    this.result,
  });

  PublishActionState copyWith({
    bool? isLoading,
    String? error,
    List<PublishProblem>? problems,
    List<PublishProblem>? warnings,
    Map<String, dynamic>? result,
  }) {
    return PublishActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      problems: problems ?? this.problems,
      warnings: warnings ?? this.warnings,
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
    AnalyticsService.instance.count('publish_started');

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
      state = PublishActionState(
        result: result,
        warnings: PublishProblems.fromResponse(result).advisory,
      );
    } on DioException catch (e) {
      // A 400 from the publish rules names each problem ("title is 21
      // characters, the limit is 20"); that is what the user needs to see,
      // not Dio's wording for a bad status code.
      final found = PublishProblems.fromErrorBody(e.response?.data);
      final message = ErrorDisplay.userMessage(ErrorMapper.map(e));
      state = PublishActionState(
        error: found.blocking.isNotEmpty
            ? PublishProblems.rejectionMessage(e.response?.data) ?? message
            : message,
        problems: found.blocking,
      );
    } catch (e) {
      state = PublishActionState(
        error: ErrorDisplay.userMessage(ErrorMapper.map(e)),
      );
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

// ── Platform Rules ──────────────────────────────────

/// The publishing rules of every platform, straight from the server, which
/// is the only place they are defined. Falls back to [fallbackPlatformGuides]
/// when the server cannot be reached so an editor still knows the limits.
final platformGuidesProvider = FutureProvider<List<PlatformGuide>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final raw = await api.publishPlatforms();
    if (raw.isEmpty) return fallbackPlatformGuides;
    return raw.map(PlatformGuide.fromJson).toList();
  } on DioException {
    return fallbackPlatformGuides;
  }
});

/// [platformGuidesProvider] as a plain list: the server's rules once they
/// have arrived, the built-in table until then. For places that only label
/// a platform or read a limit and should not wait on a future.
final currentPlatformGuidesProvider = Provider<List<PlatformGuide>>(
  (ref) =>
      ref.watch(platformGuidesProvider).valueOrNull ?? fallbackPlatformGuides,
);

/// What the last pre-publish check said about a draft.
class PublishValidationState {
  const PublishValidationState({
    this.isChecking = false,
    this.blocking = const [],
    this.advisory = const [],
    this.unavailable = false,
  });

  const PublishValidationState.initial() : this();

  const PublishValidationState.unavailable()
      : isChecking = false,
        blocking = const [],
        advisory = const [],
        unavailable = true;

  const PublishValidationState.result({
    this.blocking = const [],
    this.advisory = const [],
  })  : isChecking = false,
        unavailable = false;

  final bool isChecking;
  final List<PublishProblem> blocking;
  final List<PublishProblem> advisory;

  /// The check could not run (offline, server error). The publish button
  /// stays enabled: the server re-checks on submit anyway.
  final bool unavailable;
}

/// Asks the server to check a draft as the user writes, without publishing.
///
/// Calls are debounced and only the latest draft's result is kept, so a slow
/// answer for an earlier draft never overwrites what is on screen. What can
/// be judged without the server (length against the platform's limits) is
/// left to the editor; this only reports what needs the server's rules.
class PublishValidationNotifier extends StateNotifier<PublishValidationState> {
  PublishValidationNotifier(this._api)
      : super(const PublishValidationState.initial());

  final ApiClient _api;

  Timer? _debounce;
  int _requestSerial = 0;

  static const debounceDelay = Duration(milliseconds: 500);

  /// Checks [title], [content] and [tags] against [platformId]'s rules once
  /// the user pauses typing.
  void check({
    required String platformId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) {
    _debounce?.cancel();
    final serial = ++_requestSerial;
    // Keep what the last check said until the new answer arrives, so the
    // list does not blink on every keystroke.
    state = PublishValidationState(
      isChecking: true,
      blocking: state.blocking,
      advisory: state.advisory,
    );
    _debounce = Timer(debounceDelay, () async {
      try {
        final res = await _api.validatePublish({
          'platform': platformId,
          'title': title,
          'content': content,
          'tags': tags,
        });
        if (serial != _requestSerial || !mounted) return;
        final found = PublishProblems.fromValidation(res);
        state = PublishValidationState.result(
          blocking: found.blocking,
          advisory: found.advisory,
        );
      } catch (_) {
        if (serial != _requestSerial || !mounted) return;
        state = const PublishValidationState.unavailable();
      }
    });
  }

  /// Clears the result, e.g. when the platform selection changes.
  void reset() {
    _debounce?.cancel();
    _requestSerial++;
    state = const PublishValidationState.initial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final publishValidationProvider =
    StateNotifierProvider<PublishValidationNotifier, PublishValidationState>(
  (ref) => PublishValidationNotifier(ref.read(apiClientProvider)),
);

// ── Publish Detail ───────────────────────────────────

/// Fetches a single publish log entry by ID.
final publishDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.read(apiClientProvider);
  return api.getPublish(id);
});
