import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../compose/data/ai_repository.dart';

// ── Tag Suggestion State ───────────────────────────

/// State for AI tag suggestion.
class _TagSuggestionState {
  final bool isLoading;
  final List<String> suggestedTags;
  final Set<String> acceptedTags;
  final String? error;

  const _TagSuggestionState({
    this.isLoading = false,
    this.suggestedTags = const [],
    this.acceptedTags = const {},
    this.error,
  });

  _TagSuggestionState copyWith({
    bool? isLoading,
    List<String>? suggestedTags,
    Set<String>? acceptedTags,
    String? error,
  }) {
    return _TagSuggestionState(
      isLoading: isLoading ?? this.isLoading,
      suggestedTags: suggestedTags ?? this.suggestedTags,
      acceptedTags: acceptedTags ?? this.acceptedTags,
      error: error,
    );
  }
}

// ── Tag Suggestion Notifier ────────────────────────

/// Manages the AI tag suggestion state.
class _TagSuggestionNotifier extends StateNotifier<_TagSuggestionState> {
  final AIRepository _aiRepo;
  CancelToken? _activeToken;

  _TagSuggestionNotifier(this._aiRepo) : super(const _TagSuggestionState());

  /// Request AI-generated tag suggestions for the given content.
  Future<void> suggestTags(String content) async {
    if (content.trim().isEmpty) return;

    _activeToken?.cancel('Replaced by new request');
    _activeToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _aiRepo.chat(
        [
          const ChatMessage(
            role: 'system',
            content: 'You are a tagging assistant for a note-taking app. '
                'Analyze the text and suggest 3 to 5 relevant tags. '
                'Tags should be short (1-3 words), lowercase, and concise. '
                'Respond with ONLY a JSON array of strings, no other text. '
                'Example: ["productivity", "meeting-notes", "project-alpha"]',
          ),
          ChatMessage(
            role: 'user',
            content: 'Suggest tags for this note:\n\n$content',
          ),
        ],
        cancelToken: _activeToken,
      );

      // Parse the JSON array from the response.
      final cleaned = response.trim();
      final jsonStart = cleaned.indexOf('[');
      final jsonEnd = cleaned.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        state = state.copyWith(isLoading: false, error: 'Failed to parse tags');
        return;
      }

      final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
      // Parse without dart:convert to avoid extra import.
      final tags = _parseSimpleJsonArray(jsonStr);

      state = state.copyWith(
        isLoading: false,
        suggestedTags: tags,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Toggle acceptance of a suggested tag.
  void toggleTag(String tag) {
    final accepted = Set<String>.from(state.acceptedTags);
    if (accepted.contains(tag)) {
      accepted.remove(tag);
    } else {
      accepted.add(tag);
    }
    state = state.copyWith(acceptedTags: accepted);
  }

  @override
  void dispose() {
    _activeToken?.cancel('Disposed');
    super.dispose();
  }
}

/// Simple JSON array parser for tag strings.
/// Handles ["tag1", "tag2", "tag3"] format.
List<String> _parseSimpleJsonArray(String json) {
  // Remove brackets and split.
  final inner = json.substring(1, json.length - 1);
  if (inner.trim().isEmpty) return [];

  final tags = <String>[];
  final buffer = StringBuffer();
  bool inString = false;

  for (int i = 0; i < inner.length; i++) {
    final ch = inner[i];
    if (ch == '"' && (i == 0 || inner[i - 1] != '\\')) {
      inString = !inString;
      if (!inString && buffer.isNotEmpty) {
        tags.add(buffer.toString().trim());
        buffer.clear();
      }
    } else if (inString) {
      buffer.write(ch);
    }
  }

  return tags;
}

// ── Provider ───────────────────────────────────────

/// Provider for the tag suggestion notifier.
final _tagSuggestionProvider = StateNotifierProvider.autoDispose<
    _TagSuggestionNotifier, _TagSuggestionState>((ref) {
  final aiRepo = ref.read(aiRepositoryProvider);
  return _TagSuggestionNotifier(aiRepo);
});

// ── AI Tag Suggestion Widget ───────────────────────

/// Bottom sheet widget that shows AI-suggested tags as tappable chips.
///
/// Users must explicitly accept each tag before they are applied.
class AiTagSuggestionSheet extends ConsumerWidget {
  /// The note content to analyze for tags.
  final String content;

  /// Callback with the set of accepted tags.
  final void Function(Set<String> acceptedTags) onApply;

  const AiTagSuggestionSheet({
    super.key,
    required this.content,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(_tagSuggestionProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      maxChildSize: 0.7,
      minChildSize: 0.25,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.sell_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aiTagSuggestion,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (!state.isLoading && state.suggestedTags.isEmpty)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(_tagSuggestionProvider.notifier)
                            .suggestTags(content);
                      },
                      child: Text(l10n.suggestTags),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(child: _buildContent(context, ref, l10n, state)),
          ],
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    _TagSuggestionState state,
  ) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.analyzingContent,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  ref
                      .read(_tagSuggestionProvider.notifier)
                      .suggestTags(content);
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.suggestedTags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.label_outline,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.tapSuggestTagsDesc,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Show tag chips.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectTagsToApply,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.suggestedTags.map((tag) {
                    final isAccepted = state.acceptedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isAccepted,
                      onSelected: (_) {
                        ref
                            .read(_tagSuggestionProvider.notifier)
                            .toggleTag(tag);
                      },
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        // Apply button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.acceptedTags.isEmpty
                    ? null
                    : () {
                        onApply(state.acceptedTags);
                        Navigator.pop(context);
                      },
                child: Text(
                  l10n.applyTags(state.acceptedTags.length),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
