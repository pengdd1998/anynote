import 'dart:async';
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
import '../domain/post_template.dart';
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

  /// Selected post template (controls format/tone/structure).
  final PostTemplate? selectedTemplate;

  /// Chat history from iterative refinement (user instruction + AI response).
  final List<ChatMessage> refinementHistory;

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
    this.selectedTemplate,
    this.refinementHistory = const [],
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
    PostTemplate? selectedTemplate,
    List<ChatMessage>? refinementHistory,
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
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
      refinementHistory: refinementHistory ?? this.refinementHistory,
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

  @override
  void dispose() {
    cancel();
    super.dispose();
  }

  /// Reset state for a new composition session while keeping the notifier alive.
  void resetForNewSession() {
    cancel();
    _isProcessing = false;
    state = ComposeSessionState(sessionId: const Uuid().v4());
  }

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
  Future<bool> _checkQuota({String? quotaExceededMessage}) async {
    try {
      final quotaState = _ref.read(aiQuotaProvider);
      final quotaData = quotaState.valueOrNull;
      if (quotaData == null) return true; // No data yet, allow attempt.

      // The quota response has dailyUsed and dailyLimit fields.
      if (quotaData.isExhausted) {
        state = state.copyWith(
          isLoading: false,
          error: quotaExceededMessage ??
              'AI quota exceeded. Please wait before trying again.',
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
  ///
  /// Returns `true` if the selection changed, `false` if the request was
  /// rejected (e.g. the note limit was hit). Callers must only update their
  /// local UI state when this returns `true`.
  bool toggleNoteSelection(
    String noteId,
    String plainContent, {
    String? maxNotesMessage,
  }) {
    final ids = List<String>.from(state.selectedNoteIds);
    final contents = Map<String, String>.from(state.noteContents);

    if (ids.contains(noteId)) {
      ids.remove(noteId);
      contents.remove(noteId);
    } else {
      // Enforce maximum selected notes limit.
      if (ids.length >= maxSelectedNotes) {
        state = state.copyWith(
          error: maxNotesMessage ??
              'You can select at most $maxSelectedNotes notes. '
                  'Deselect some notes before adding more.',
        );
        return false;
      }
      ids.add(noteId);
      contents[noteId] = plainContent;
    }

    state = state.copyWith(selectedNoteIds: ids, noteContents: contents);
    return true;
  }

  /// Set the composition topic.
  void setTopic(String topic) {
    state = state.copyWith(topic: topic);
  }

  /// Set the target platform style.
  void setPlatformStyle(String style) {
    state = state.copyWith(platformStyle: style);
  }

  /// Set the selected post template (controls format/tone/structure).
  ///
  /// Passing `null` explicitly clears the selection (see [clearTemplate]).
  void setTemplate(PostTemplate? template) {
    if (template == null) {
      clearTemplate();
      return;
    }
    state = state.copyWith(selectedTemplate: template);
  }

  /// Explicitly clear the selected post template.
  ///
  /// [ComposeSessionState.copyWith] cannot assign a nullable field back to
  /// null (`selectedTemplate ?? this.selectedTemplate` keeps the old value),
  /// so the state is reconstructed here with a raw field assignment.
  void clearTemplate() {
    final s = state;
    state = ComposeSessionState(
      sessionId: s.sessionId,
      stage: s.stage,
      selectedNoteIds: s.selectedNoteIds,
      noteContents: s.noteContents,
      topic: s.topic,
      platformStyle: s.platformStyle,
      selectedTemplate: null,
      refinementHistory: s.refinementHistory,
      clusters: s.clusters,
      selectedClusterIndices: s.selectedClusterIndices,
      outline: s.outline,
      draft: s.draft,
      isLoading: s.isLoading,
      error: s.error,
    );
  }

  // ── Stage 1: Cluster ───────────────────────────

  /// IDs of selected notes with non-empty content, in selection order.
  ///
  /// Stage-1 cluster [ClusterModel.noteIndices] refer to this list — it is
  /// the exact per-note ordering sent to the LLM — not to
  /// [ComposeSessionState.selectedNoteIds].
  List<String> get _promptNoteIds => state.selectedNoteIds
      .where((id) => (state.noteContents[id] ?? '').isNotEmpty)
      .toList();

  /// Request AI clustering of selected notes.
  Future<void> generateClusters({
    String? maxContentMessage,
    String? quotaExceededMessage,
  }) async {
    if (state.selectedNoteIds.isEmpty || state.topic.isEmpty) return;
    if (_isProcessing) return;

    // Validate total content size before sending.
    if (state.totalContentChars > maxTotalContentChars) {
      state = state.copyWith(
        error: maxContentMessage ??
            'Total content exceeds ${maxTotalContentChars ~/ 1000}K characters. '
                'Please select fewer notes or shorten the content.',
      );
      return;
    }

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota(quotaExceededMessage: quotaExceededMessage)) {
        return;
      }

      final promptNoteIds = _promptNoteIds;
      final noteTexts =
          promptNoteIds.map((id) => state.noteContents[id] ?? '').toList();

      // Join with the unique sentinel so multi-line notes survive the
      // truncate-then-split round trip; splitting on a bare '\n' would
      // shatter a multi-line note into pseudo-notes and corrupt the cluster
      // note_indices mapping.
      const separator = '\n$kNoteSeparator\n';
      final combinedText = noteTexts.join(separator);
      var promptText =
          PromptBuilder.truncateToLimit(combinedText, maxTotalContentChars);
      // If truncation destroyed a sentinel, back off to the last complete
      // marker so every split entry is exactly one note and the entry order
      // stays aligned with [promptNoteIds]. (A cut before the first sentinel
      // still yields exactly one entry: a prefix of the first note.)
      if (promptText.length < combinedText.length) {
        final lastSep = promptText.lastIndexOf(separator);
        if (lastSep != -1) {
          promptText = promptText.substring(0, lastSep);
        }
      }
      final truncatedNotes = promptText.split(separator);

      final prompt = _promptBuilder.buildClusterPrompt(
        truncatedNotes,
        state.topic,
        template: state.selectedTemplate,
      );
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
  Future<void> generateOutline({String? quotaExceededMessage}) async {
    if (state.selectedClusterIndices.isEmpty) return;
    if (_isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota(quotaExceededMessage: quotaExceededMessage)) {
        return;
      }

      final selectedClusters = state.selectedClusterIndices
          .map((i) => state.clusters[i].toJson())
          .toList();

      final prompt = _promptBuilder.buildOutlinePrompt(
        selectedClusters,
        state.platformStyle,
        topic: state.topic,
        template: state.selectedTemplate,
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
  Future<void> expandToDraft({String? quotaExceededMessage}) async {
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
      if (!await _checkQuota(quotaExceededMessage: quotaExceededMessage)) {
        return;
      }

      // Gather source notes from selected clusters. Cluster note_indices
      // refer to the filtered prompt-note list (non-empty content, selection
      // order) — the exact ordering sent during clustering — not to raw
      // selectedNoteIds.
      final promptNoteIds = _promptNoteIds;
      final sourceNotes = <String>[];
      for (final index in state.selectedClusterIndices) {
        if (index < state.clusters.length) {
          final cluster = state.clusters[index];
          for (final noteIdx in cluster.noteIndices) {
            if (noteIdx >= 0 && noteIdx < promptNoteIds.length) {
              final noteId = promptNoteIds[noteIdx];
              final content = state.noteContents[noteId] ?? '';
              if (content.isNotEmpty) sourceNotes.add(content);
            }
          }
        }
      }

      // Apply the global char budget per note so truncation can never merge
      // notes or shift their order.
      final limitedSources = <String>[];
      var remaining = maxTotalContentChars;
      for (final content in sourceNotes) {
        if (remaining <= 0) break;
        final piece = PromptBuilder.truncateToLimit(content, remaining);
        limitedSources.add(piece);
        remaining -= piece.length;
      }

      final prompt = _promptBuilder.buildExpandPrompt(
        state.outline!.toJson(),
        limitedSources,
        topic: state.topic,
        template: state.selectedTemplate,
      );

      final buffer = StringBuffer();
      Timer? throttleTimer;

      await for (final chunk in _aiRepo.chatStream(
        [ChatMessage(role: 'user', content: prompt)],
        cancelToken: token,
      ).timeout(
        const Duration(minutes: 3),
        onTimeout: (sink) {
          debugPrint('[ComposeProviders] expandToDraft stream timed out');
          sink.close();
        },
      )) {
        buffer.write(chunk);
        throttleTimer ??= Timer(const Duration(milliseconds: 125), () {
          throttleTimer = null;
          state = state.copyWith(draft: buffer.toString());
        });
      }
      throttleTimer?.cancel();
      state = state.copyWith(draft: buffer.toString(), isLoading: false);
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
  Future<void> adaptStyle({String? quotaExceededMessage}) async {
    if (state.draft.isEmpty) return;
    if (_isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota(quotaExceededMessage: quotaExceededMessage)) {
        return;
      }

      final prompt = _promptBuilder.buildStyleAdaptPrompt(
        state.draft,
        state.platformStyle,
        template: state.selectedTemplate,
      );

      final buffer = StringBuffer();
      Timer? throttleTimer;
      await for (final chunk in _aiRepo.chatStream(
        [ChatMessage(role: 'user', content: prompt)],
        cancelToken: token,
      ).timeout(
        const Duration(minutes: 3),
        onTimeout: (sink) {
          debugPrint('[ComposeProviders] adaptStyle stream timed out');
          sink.close();
        },
      )) {
        buffer.write(chunk);
        throttleTimer ??= Timer(const Duration(milliseconds: 125), () {
          throttleTimer = null;
          state = state.copyWith(draft: buffer.toString());
        });
      }
      throttleTimer?.cancel();
      state = state.copyWith(draft: buffer.toString(), isLoading: false);
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

  // ── Stage 5: Chat-based refinement ─────────────

  /// Refine the draft via a chat instruction.
  ///
  /// The LLM receives the template context + current draft + prior refinement
  /// history + the new instruction, and streams the FULL updated draft back.
  /// The draft updates in real-time during streaming.
  Future<void> refineDraft(
    String instruction, {
    String? quotaExceededMessage,
  }) async {
    if (state.draft.isEmpty || _isProcessing) return;

    _isProcessing = true;
    state = state.copyWith(isLoading: true, error: null);
    final token = _freshToken();

    try {
      if (!await _checkQuota(quotaExceededMessage: quotaExceededMessage)) {
        return;
      }

      final systemPrompt =
          _promptBuilder.buildRefineSystemPrompt(state.selectedTemplate);

      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(
          role: 'user',
          content: 'Here is the current draft. Keep it as context and apply '
              'the user\'s refinements:\n\n${state.draft}',
        ),
        ...state.refinementHistory,
        ChatMessage(role: 'user', content: instruction),
      ];

      // Remember the draft as it was before streaming so an empty response
      // can be rolled back.
      final previousDraft = state.draft;

      final buffer = StringBuffer();
      Timer? throttleTimer;

      await for (final chunk in _aiRepo
          .chatStream(
        messages,
        cancelToken: token,
      )
          .timeout(
        const Duration(minutes: 3),
        onTimeout: (sink) {
          debugPrint('[ComposeProviders] refineDraft stream timed out');
          sink.close();
        },
      )) {
        buffer.write(chunk);
        throttleTimer ??= Timer(const Duration(milliseconds: 125), () {
          throttleTimer = null;
          state = state.copyWith(draft: buffer.toString());
        });
      }
      throttleTimer?.cancel();

      final result = buffer.toString().trim();
      if (result.isEmpty) {
        // The stream produced nothing usable: restore the previous draft and
        // leave the refinement history untouched (no turns for an empty
        // response).
        state = state.copyWith(
          draft: previousDraft,
          isLoading: false,
          error: 'The AI returned an empty response. Please try again.',
        );
        return;
      }

      state = state.copyWith(
        draft: result,
        isLoading: false,
        refinementHistory: [
          ...state.refinementHistory,
          ChatMessage(role: 'user', content: instruction),
          ChatMessage(role: 'assistant', content: result),
        ],
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

      // After a session restore the vault may still be locked — try the
      // stored keys before giving up; encryptForItem throws when locked.
      if (!crypto.isUnlocked) {
        await crypto.unlock();
      }
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
  try {
    return db.notesDao.watchAllNotes();
  } catch (e) {
    debugPrint('[ComposeProviders] notesDao.watchAllNotes() failed: $e');
    return Stream.value([]);
  }
});

/// Provides generated content history for the compose home screen.
final generatedContentsProvider = StreamProvider<List<dynamic>>((ref) {
  final db = ref.watch(databaseProvider);
  try {
    return db.generatedContentsDao.watchAll();
  } catch (e) {
    debugPrint('[ComposeProviders] generatedContentsDao.watchAll() failed: $e');
    return Stream.value([]);
  }
});

// ── Post Template Providers ────────────────────────

/// Watches all post templates (built-in + user-created) from the database.
final allPostTemplatesProvider = StreamProvider<List<PostTemplate>>((ref) {
  final db = ref.watch(databaseProvider);
  try {
    return db.postTemplateDao.watchAll().map((rows) => rows
        .map((r) => PostTemplate(
              id: r.id,
              name: r.name,
              description: r.description,
              systemPrompt: r.systemPrompt,
              structureHint: r.structureHint,
              toneHint: r.toneHint,
              isBuiltIn: r.isBuiltIn,
              createdAt: r.createdAt,
            ))
        .toList());
  } catch (e) {
    debugPrint('[ComposeProviders] postTemplateDao.watchAll() failed: $e');
    return Stream.value(kBuiltInTemplates);
  }
});

/// Extracts a [PostTemplate] from a sample post via the AI agent.
/// Returns the extracted template, or null on failure.
Future<PostTemplate?> extractTemplateFromPost(
  String samplePost, {
  required dynamic ref,
}) async {
  final aiRepo = ref.read(aiRepositoryProvider);
  final promptBuilder = PromptBuilder();

  try {
    final prompt = promptBuilder.buildExtractTemplatePrompt(samplePost);
    final response = await aiRepo.chat(
      [ChatMessage(role: 'user', content: prompt)],
    );

    final jsonStr = ResponseParser.extractJson(response);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;

    return PostTemplate.create(
      name: json['name'] as String? ?? 'Extracted Template',
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      structureHint: json['structureHint'] as String?,
      toneHint: json['toneHint'] as String?,
    );
  } catch (e) {
    debugPrint('[ComposeProviders] extractTemplateFromPost failed: $e');
    return null;
  }
}
