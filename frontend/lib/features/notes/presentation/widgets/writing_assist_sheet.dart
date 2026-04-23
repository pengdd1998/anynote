import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../compose/data/ai_repository.dart';

// ── Writing Assist State ───────────────────────────

/// State for the grammar/writing polish AI operation.
class _WritingAssistState {
  final bool isLoading;
  final String correctedText;
  final String? error;

  const _WritingAssistState({
    this.isLoading = false,
    this.correctedText = '',
    this.error,
  });

  _WritingAssistState copyWith({
    bool? isLoading,
    String? correctedText,
    String? error,
  }) {
    return _WritingAssistState(
      isLoading: isLoading ?? this.isLoading,
      correctedText: correctedText ?? this.correctedText,
      error: error,
    );
  }
}

// ── Writing Assist Notifier ────────────────────────

/// Manages the grammar/writing polish state.
class _WritingAssistNotifier extends StateNotifier<_WritingAssistState> {
  final AIRepository _aiRepo;
  CancelToken? _activeToken;

  _WritingAssistNotifier(this._aiRepo) : super(const _WritingAssistState());

  /// Run grammar check and polish on the given text.
  Future<void> polishText(String text) async {
    if (text.trim().isEmpty) return;

    _activeToken?.cancel('Replaced by new request');
    _activeToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null, correctedText: '');

    final buffer = StringBuffer();

    try {
      await for (final chunk in _aiRepo.chatStream(
        [
          const ChatMessage(
            role: 'system',
            content: 'You are a writing assistant. Fix grammar, spelling, and '
                'punctuation errors in the user text. Also improve clarity '
                'and readability while preserving the original meaning and '
                'tone. Output ONLY the corrected text with no explanation '
                'or commentary. Respond in the same language as the input.',
          ),
          ChatMessage(
            role: 'user',
            content: text,
          ),
        ],
        cancelToken: _activeToken,
      )) {
        buffer.write(chunk);
        state = state.copyWith(correctedText: buffer.toString());
      }

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _activeToken?.cancel('Disposed');
    super.dispose();
  }
}

// ── Provider ───────────────────────────────────────

/// Provider for the writing assist notifier.
final _writingAssistProvider = StateNotifierProvider.autoDispose<
    _WritingAssistNotifier, _WritingAssistState>((ref) {
  final aiRepo = ref.read(aiRepositoryProvider);
  return _WritingAssistNotifier(aiRepo);
});

// ── Writing Assist Sheet ───────────────────────────

/// Bottom sheet for grammar checking and writing polish with diff display.
///
/// Shows the original vs corrected text with a diff visualization,
/// and Accept All / Reject actions.
class WritingAssistSheet extends ConsumerWidget {
  /// The original text to polish.
  final String originalText;

  /// Callback to replace the text with the polished version.
  final void Function(String corrected) onAccept;

  const WritingAssistSheet({
    super.key,
    required this.originalText,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(_writingAssistProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.35,
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
                    Icons.spellcheck,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.writingPolish,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (!state.isLoading && state.correctedText.isEmpty)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(_writingAssistProvider.notifier)
                            .polishText(originalText);
                      },
                      child: Text(l10n.checkGrammar),
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
    _WritingAssistState state,
  ) {
    if (state.isLoading && state.correctedText.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.checkingGrammar,
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
                      .read(_writingAssistProvider.notifier)
                      .polishText(originalText);
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.correctedText.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_note,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.writingPolishDesc,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Show diff view.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original label
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.original,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    originalText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Corrected label
                Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.corrected,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _DiffView(
                  original: originalText,
                  corrected: state.correctedText,
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
              ],
            ),
          ),
        ),
        // Action buttons
        if (!state.isLoading)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.reject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        onAccept(state.correctedText);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(l10n.acceptAll),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Diff View Widget ───────────────────────────────

/// Simple diff visualization between original and corrected text.
///
/// Highlights changed lines with a colored background.
class _DiffView extends StatelessWidget {
  final String original;
  final String corrected;

  const _DiffView({required this.original, required this.corrected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final originalLines = original.split('\n');
    final correctedLines = corrected.split('\n');

    // Compute a simple line-level diff.
    final spans = <TextSpan>[];

    for (int i = 0; i < correctedLines.length; i++) {
      final correctedLine = correctedLines[i];
      final originalLine = i < originalLines.length ? originalLines[i] : null;

      final isChanged = originalLine == null || originalLine != correctedLine;

      if (isChanged) {
        spans.add(
          TextSpan(
            text: correctedLine,
            style: TextStyle(
              backgroundColor:
                  colorScheme.primaryContainer.withValues(alpha: 0.4),
              color: colorScheme.onSurface,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: correctedLine,
            style: TextStyle(color: colorScheme.onSurface),
          ),
        );
      }

      if (i < correctedLines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, height: 1.5),
          children: spans,
        ),
      ),
    );
  }
}
