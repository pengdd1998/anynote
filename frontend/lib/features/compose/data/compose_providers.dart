import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/error/error_mapper.dart';
import '../../settings/data/settings_providers.dart';
import '../domain/cluster_model.dart';
import '../domain/outline_model.dart';
import '../domain/prompt_builder.dart';
import '../domain/response_parser.dart';
import 'ai_repository.dart';

// ── Content Limits ─────────────────────────────────

/// Maximum number of notes that can be selected for a single compose session.
const int maxSelectedNotes = 10;

/// Maximum total character count across all selected note contents.
const int maxTotalContentChars = 100000; // 100K chars

// ── Compose Stage ──────────────────────────────────

/// Stages of the AI composition pipeline.
enum ComposeStage {
  /// User selects notes and provides a topic.
  selectNotes,

  /// AI clusters notes by theme; user selects clusters.
  cluster,

  /// AI generates outline; user edits and reorders.
  outline,

  /// AI expands outline into full draft with streaming display.
  editor,
}

// ── Compose Session State ──────────────────────────

/// Immutable state for a single compose session.
class ComposeSessionState {
  final String sessionId;
  final ComposeStage stage;

  /// Note IDs selected by the user.
  final List<String> selectedNoteIds;

  /// Plaintext content of selected notes, keyed by note ID.
  final Map<String, String> noteContents;

  /// User-provided topic for the composition.
  final String topic;

  /// Target platform style (e.g. 'generic', 'xhs', 'twitter').
  final String platformStyle;

  /// AI-generated clusters.
  final List<ClusterModel> clusters;

  /// Indices of selected clusters.
  final Set<int> selectedClusterIndices;

  /// AI-generated outline.
  final OutlineModel? outline;

  /// Final draft text (accumulated from streaming).
  final String draft;

  /// Whether an AI operation is in progress.
  final bool isLoading;

  /// Error message to display, if any.
  final String? error;

  const ComposeSessionState({
    required this.sessionId,
    this.stage = ComposeStage.selectNotes,
    this.selectedNoteIds = const [],
    this.noteContents = const {},
    this.topic = '',
    this.platformStyle = 'generic',
    this.clusters = const [],
    this.selectedClusterIndices = const {},
    this.outline,
    this.draft = '',
    this.isLoading = false,
    this.error,
  });

  ComposeSessionState copyWith({
    ComposeStage? stage,
    List<String>? selectedNoteIds,
    Map<String, String>? noteContents,
    String? topic,
    String? platformStyle,
    List<ClusterModel>? clusters,
    Set<int>? selectedClusterIndices,
    OutlineModel? outline,
    String? draft,
    bool? isLoading,
    String? error,
  }) {
    return ComposeSessionState(
      sessionId: sessionId,
      stage: stage ?? this.stage,
      selectedNoteIds: selectedNoteIds ?? this.selectedNoteIds,
      noteContents: noteContents ?? this.noteContents,
      topic: topic ?? this.topic,
      platformStyle: platformStyle ?? this.platformStyle,
      clusters: clusters ?? this.clusters,
      selectedClusterIndices:
          selectedClusterIndices ?? this.selectedClusterIndices,
      outline: outline ?? this.outline,
      draft: draft ?? this.draft,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Total character count across all selected note contents.
  int get totalContentChars =>
      noteContents.values.fold(0, (sum, c) => sum + c.length);
}

// ── Compose Session Notifier ───────────────────────

/// Manages state for a single compose session, orchestrating all four
/// AI pipeline stages through the AI repository and prompt builder.
class ComposeSessionNotifier extends StateNotifier<ComposeSessionState> {
  final Ref _ref;

  /// Concurrency guard: true while an AI operation is in flight.
  bool _isProcessing = false;

  /// Active Dio CancelToken for stream cancellation.
  CancelToken? _activeToken;

  ComposeSessionNotifier(this._ref, String sessionId)
      : super(ComposeSessionState(sessionId: sessionId));

  AIRepository get _aiRepo => _ref.read(aiRepositoryProvider);
  PromptBuilder get _promptBuilder => PromptBuilder();

  // ── CancelToken lifecycle ──────────────────────

  /// Cancel any in-flight AI operation and dispose the token.
  void cancel() {
    _activeToken?.cancel('Compose session cancelled');
    _activeToken = null;
  }

  /// Create a fresh CancelToken, cancelling any existing one first.
  CancelToken _freshToken() {
    _activeToken?.cancel('Replaced by new request');
    _activeToken = CancelToken();
    return _activeToken!;
  }

  // ── Quota pre-check ────────────────────────────

  /// Check the AI quota before starting an operation.
  /// Returns `true` if the user has remaining quota, `false` otherwise.
  /// When quota is exceeded, sets the error on the state.
  Future<bool> _checkQuota() async {
    try {
      final quotaState = _ref.read(aiQuotaProvider);
      final quotaData = quotaState.valueOrNull;
      if (quotaData == null) return true; // No data yet, allow attempt.

      // The quota response has dailyUsed and dailyLimit fields.
      if (quotaData.isExhausted) {
        state = state.copyWith(
          isLoading: false,
          error: 'AI quota exceeded. Please wait before trying again.',
        );
        return false;
      }
      return true;
    } catch (e) {
      // If quota check fails, allow the operation to proceed.
      // The server will enforce the limit regardless.
      debugPrint('[ComposeProviders] quota check failed, proceeding: $e');
      return true;
    }
  }

  // ── Note selection ─────────────────────────────

  /// Toggle a note's inclusion in the selection.
  /// Enforces [maxSelectedNotes] limit when adding a new note.
  void toggleNoteSelection(String noteId, String plainContent) {
    final ids = List<String>.from(state.selectedNoteIds);
    final contents = Map<String, String>.from(state.noteContents);

    if (ids.contains(noteId)) {
      ids.remove(noteId);
      contents.remove(noteId);
    } else {
      // Enforce maximum selected notes limit.
      if (ids.length >= maxSelectedNotes) {
        state = state.copyWith(
          error: 'You can select at most $maxSelectedNotes notes. '
              'Deselect some notes before adding more.',
        );
        return;
      }
      ids.add(noteId);
      contents[noteId] = plainContent;
    }

    state = state.copyWith(selectedNoteIds: ids, noteContents: contents);
  }

  /// Set the composition topic.
  void setTopic(String topic) {
    state = state.copyWith(topic: topic);
  }

  /// Set the target platform style.
  void setPlatformStyle(String style) {
    state = state.copyWith(platformStyle: style);
  }

  // ── Stage 1: Cluster ───────────────────────────

  /// Request AI clustering of selected notes.
  Future<void> generateClusters() async {
    if (state.selectedNoteIds.isEmpty || state.topic.isEmpty) return;
    if (_isProcessing) return;

    // Validate total content size before sending.
    if (state.totalContentChars > maxTotalContentChars) {
      state = state.copyWith(
        error:
            'Total content exceeds ${maxTotalContentChars ~/ 1000}K characters. '
            'Please select fewer notes or shorten the content.',
      );
      return;
    }

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota()) return;

      final noteTexts = state.selectedNoteIds
          .map((id) => state.noteContents[id] ?? '')
          .where((c) => c.isNotEmpty)
          .toList();

      final combinedText = noteTexts.join('\n');
      final truncatedText =
          PromptBuilder.truncateToLimit(combinedText, maxTotalContentChars);
      final truncatedNotes = truncatedText.split('\n');

      final prompt =
          _promptBuilder.buildClusterPrompt(truncatedNotes, state.topic);
      final response = await _aiRepo.chat(
        [ChatMessage(role: 'user', content: prompt)],
        cancelToken: token,
      );

      // Parse JSON from AI response.
      final jsonStr = ResponseParser.extractJson(response);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final clusterList = (json['clusters'] as List)
          .map((c) => ClusterModel.fromJson(c as Map<String, dynamic>))
          .toList();

      // Select all clusters by default.
      final allIndices = Set<int>.from(
        List.generate(clusterList.length, (i) => i),
      );

      state = state.copyWith(
        stage: ComposeStage.cluster,
        clusters: clusterList,
        selectedClusterIndices: allIndices,
        isLoading: false,
      );
    } catch (e) {
      final appError = ErrorMapper.map(e);
      state = state.copyWith(
        isLoading: false,
        error: appError.message,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Toggle selection of a cluster by index.
  void toggleClusterSelection(int index) {
    final selected = Set<int>.from(state.selectedClusterIndices);
    if (selected.contains(index)) {
      selected.remove(index);
    } else {
      selected.add(index);
    }
    state = state.copyWith(selectedClusterIndices: selected);
  }

  // ── Stage 2: Outline ───────────────────────────

  /// Generate an outline from selected clusters.
  Future<void> generateOutline() async {
    if (state.selectedClusterIndices.isEmpty) return;
    if (_isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota()) return;

      final selectedClusters = state.selectedClusterIndices
          .map((i) => state.clusters[i].toJson())
          .toList();

      final prompt = _promptBuilder.buildOutlinePrompt(
        selectedClusters,
        state.platformStyle,
      );

      final response = await _aiRepo.chat(
        [ChatMessage(role: 'user', content: prompt)],
        cancelToken: token,
      );

      final jsonStr = ResponseParser.extractJson(response);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final outline = OutlineModel.fromJson(json);

      state = state.copyWith(
        stage: ComposeStage.outline,
        outline: outline,
        isLoading: false,
      );
    } catch (e) {
      final appError = ErrorMapper.map(e);
      state = state.copyWith(
        isLoading: false,
        error: appError.message,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Update the outline (user edits).
  void updateOutline(OutlineModel outline) {
    state = state.copyWith(outline: outline);
  }

  /// Reorder outline sections.
  void reorderSection(int oldIndex, int newIndex) {
    if (state.outline == null) return;
    final sections = List<OutlineSection>.from(state.outline!.sections);
    if (newIndex > sections.length) newIndex = sections.length;
    final item = sections.removeAt(oldIndex);
    sections.insert(newIndex, item);
    state = state.copyWith(
      outline: OutlineModel(title: state.outline!.title, sections: sections),
    );
  }

  // ── Stage 3: Expand to draft ───────────────────

  /// Expand the outline into a full draft using streaming.
  Future<void> expandToDraft() async {
    if (state.outline == null) return;
    if (_isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(
      stage: ComposeStage.editor,
      isLoading: true,
      draft: '',
      error: null,
    );
    final token = _freshToken();

    try {
      if (!await _checkQuota()) return;

      // Gather source notes from selected clusters.
      final sourceNotes = <String>[];
      for (final index in state.selectedClusterIndices) {
        if (index < state.clusters.length) {
          final cluster = state.clusters[index];
          for (final noteIdx in cluster.noteIndices) {
            if (noteIdx < state.selectedNoteIds.length) {
              final noteId = state.selectedNoteIds[noteIdx];
              sourceNotes.add(state.noteContents[noteId] ?? '');
            }
          }
        }
      }

      final combinedSource = sourceNotes.where((s) => s.isNotEmpty).join('\n');
      final truncatedSource =
          PromptBuilder.truncateToLimit(combinedSource, maxTotalContentChars);

      final prompt = _promptBuilder.buildExpandPrompt(
        state.outline!.toJson(),
        truncatedSource.split('\n'),
      );

      final buffer = StringBuffer();

      await for (final chunk in _aiRepo.chatStream(
        [ChatMessage(role: 'user', content: prompt)],
        cancelToken: token,
      )) {
        buffer.write(chunk);
        state = state.copyWith(draft: buffer.toString());
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      final appError = ErrorMapper.map(e);
      state = state.copyWith(
        isLoading: false,
        error: appError.message,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Apply platform style adaptation to the current draft.
  Future<void> adaptStyle() async {
    if (state.draft.isEmpty) return;
    if (_isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota()) return;

      final prompt = _promptBuilder.buildStyleAdaptPrompt(
        state.draft,
        state.platformStyle,
      );

      final buffer = StringBuffer();
      await for (final chunk in _aiRepo.chatStream(
        [ChatMessage(role: 'user', content: prompt)],
        cancelToken: token,
      )) {
        buffer.write(chunk);
        state = state.copyWith(draft: buffer.toString());
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      final appError = ErrorMapper.map(e);
      state = state.copyWith(
        isLoading: false,
        error: appError.message,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// Manually update the draft text.
  void updateDraft(String text) {
    state = state.copyWith(draft: text);
  }

  /// Save the draft as an encrypted note via Drift database.
  Future<String?> saveDraftAsNote() async {
    if (state.draft.isEmpty) return null;

    try {
      final db = _ref.read(databaseProvider);
      final crypto = _ref.read(cryptoServiceProvider);
      final noteId = const Uuid().v4();

      final encryptedContent = await crypto.encryptForItem(noteId, state.draft);
      final title = state.outline?.title ?? 'AI Composition';
      final encryptedTitle = await crypto.encryptForItem(noteId, title);

      await db.notesDao.createNote(
        id: noteId,
        encryptedContent: encryptedContent,
        encryptedTitle: encryptedTitle,
        plainContent: state.draft,
        plainTitle: title,
      );

      return noteId;
    } catch (e) {
      final appError = ErrorMapper.map(e);
      state = state.copyWith(error: appError.message);
      return null;
    }
  }

  /// Clear the error message.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ── Providers ─────────────────────────────────────

/// Holds the active compose session ID. Null when no session is active.
final composeSessionIdProvider = StateProvider<String?>((ref) => null);

/// Provides the ComposeSessionNotifier for the current session.
/// The session is created on demand when first accessed.
final composeSessionProvider =
    StateNotifierProvider<ComposeSessionNotifier, ComposeSessionState>((ref) {
  var sessionId = ref.watch(composeSessionIdProvider);
  // If no session exists yet, create a placeholder. The UI will set a real ID.
  sessionId ??= const Uuid().v4();
  return ComposeSessionNotifier(ref, sessionId);
});

/// Starts a new compose session, returning the session ID.
/// Use this to create a fresh session before navigating to the flow.
final startComposeSessionProvider = Provider<String Function()>((ref) {
  return () {
    final sessionId = const Uuid().v4();
    ref.read(composeSessionIdProvider.notifier).state = sessionId;
    return sessionId;
  };
});

/// Provides the list of notes from the local database for selection.
final notesForSelectionProvider = StreamProvider<List<dynamic>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchAllNotes();
});

/// Provides generated content history for the compose home screen.
final generatedContentsProvider = StreamProvider<List<dynamic>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.generatedContentsDao.watchAll();
});
