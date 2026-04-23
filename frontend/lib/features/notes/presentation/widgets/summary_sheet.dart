import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../compose/data/ai_repository.dart';

// ── Summary State ──────────────────────────────────

/// State for the summary AI operation.
class _SummaryState {
  final bool isLoading;
  final String summary;
  final String? error;

  const _SummaryState({
    this.isLoading = false,
    this.summary = '',
    this.error,
  });

  _SummaryState copyWith({
    bool? isLoading,
    String? summary,
    String? error,
  }) {
    return _SummaryState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      error: error,
    );
  }
}

// ── Summary Notifier ───────────────────────────────

/// Manages the AI summary generation state.
class _SummaryNotifier extends StateNotifier<_SummaryState> {
  final AIRepository _aiRepo;
  CancelToken? _activeToken;

  _SummaryNotifier(this._aiRepo) : super(const _SummaryState());

  /// Generate a summary for the given text content.
  Future<void> generateSummary(String content) async {
    if (content.trim().isEmpty) return;

    _activeToken?.cancel('Replaced by new request');
    _activeToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null);

    final buffer = StringBuffer();

    try {
      await for (final chunk in _aiRepo.chatStream(
        [
          const ChatMessage(
            role: 'system',
            content:
                'You are a helpful assistant that summarizes text concisely. '
                'Provide a clear, accurate summary that captures the key points. '
                'Keep the summary to 2-4 sentences unless the content is very long. '
                'Respond in the same language as the input text.',
          ),
          ChatMessage(
            role: 'user',
            content: 'Please summarize the following text:\n\n$content',
          ),
        ],
        cancelToken: _activeToken,
      )) {
        buffer.write(chunk);
        state = state.copyWith(summary: buffer.toString());
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _activeToken?.cancel('Disposed');
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────

/// Provider for the summary notifier, scoped to the sheet lifecycle.
final _summaryProvider =
    StateNotifierProvider.autoDispose<_SummaryNotifier, _SummaryState>((ref) {
  final aiRepo = ref.read(aiRepositoryProvider);
  return _SummaryNotifier(aiRepo);
});

// ── Summary Sheet ──────────────────────────────────

/// Bottom sheet for generating and displaying an AI summary of note content.
///
/// Shows a streaming summary with Copy and Replace actions.
class SummarySheet extends ConsumerWidget {
  /// The text content to summarize.
  final String content;

  /// Callback to replace the editor content with the summary.
  final void Function(String summary) onReplace;

  const SummarySheet({
    super.key,
    required this.content,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(_summaryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
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
                  color: Colors.grey.shade300,
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
                    Icons.summarize_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.smartSummary,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: state.summary.isEmpty &&
                      !state.isLoading &&
                      state.error == null
                  ? _buildPrompt(context, ref, l10n)
                  : _buildResult(context, ref, l10n, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrompt(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.summaryPromptDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(_summaryProvider.notifier).generateSummary(content);
              },
              icon: const Icon(Icons.summarize_outlined),
              label: Text(l10n.generateSummary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    _SummaryState state,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        if (state.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () {
                    ref
                        .read(_summaryProvider.notifier)
                        .generateSummary(content);
                  },
                ),
              ],
            ),
          ),

        if (state.isLoading && state.summary.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: CircularProgressIndicator(),
            ),
          ),

        if (state.summary.isNotEmpty)
          SelectableText(
            state.summary,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),

        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Action buttons
        if (state.summary.isNotEmpty && !state.isLoading)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: state.summary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.copiedToClipboard)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(l10n.copy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    onReplace(state.summary);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(l10n.replace),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
