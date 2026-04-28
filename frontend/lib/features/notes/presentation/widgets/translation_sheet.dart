import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../compose/data/ai_repository.dart';

// ── Supported Languages ────────────────────────────

/// Language options for AI translation.
class _LanguageOption {
  final String code;
  final String nameKey;

  const _LanguageOption(this.code, this.nameKey);
}

const _languages = [
  _LanguageOption('en', 'english'),
  _LanguageOption('zh', 'chinese'),
  _LanguageOption('ja', 'japanese'),
  _LanguageOption('ko', 'korean'),
  _LanguageOption('fr', 'french'),
  _LanguageOption('de', 'german'),
  _LanguageOption('es', 'spanish'),
];

// ── Translation State ──────────────────────────────

/// State for the translation AI operation.
class _TranslationState {
  final bool isLoading;
  final String translatedText;
  final String? error;
  final String targetLanguage;

  const _TranslationState({
    this.isLoading = false,
    this.translatedText = '',
    this.error,
    this.targetLanguage = 'en',
  });

  _TranslationState copyWith({
    bool? isLoading,
    String? translatedText,
    String? error,
    String? targetLanguage,
  }) {
    return _TranslationState(
      isLoading: isLoading ?? this.isLoading,
      translatedText: translatedText ?? this.translatedText,
      error: error,
      targetLanguage: targetLanguage ?? this.targetLanguage,
    );
  }
}

// ── Translation Notifier ───────────────────────────

/// Manages the AI translation state.
class _TranslationNotifier extends StateNotifier<_TranslationState> {
  final AIRepository _aiRepo;
  CancelToken? _activeToken;

  _TranslationNotifier(this._aiRepo) : super(const _TranslationState());

  /// Change the target language.
  void setTargetLanguage(String code) {
    state = state.copyWith(targetLanguage: code);
  }

  /// Translate the given text to the selected target language.
  Future<void> translate(String text) async {
    if (text.trim().isEmpty) return;

    _activeToken?.cancel('Replaced by new request');
    _activeToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null, translatedText: '');

    final langName = _languages
            .where((l) => l.code == state.targetLanguage)
            .map((l) => l.nameKey)
            .firstOrNull ??
        'English';

    final buffer = StringBuffer();

    try {
      await for (final chunk in _aiRepo.chatStream(
        [
          ChatMessage(
            role: 'system',
            content:
                'You are a professional translator. Translate the user text '
                'to $langName. Output ONLY the translated text with no extra '
                'commentary. Preserve the original formatting (paragraphs, '
                'lists, etc.). If the text is already in the target language, '
                'return it unchanged.',
          ),
          ChatMessage(
            role: 'user',
            content: text,
          ),
        ],
        cancelToken: _activeToken,
      )) {
        buffer.write(chunk);
        state = state.copyWith(translatedText: buffer.toString());
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

/// Provider for the translation notifier.
final _translationProvider =
    StateNotifierProvider.autoDispose<_TranslationNotifier, _TranslationState>(
        (ref) {
  final aiRepo = ref.read(aiRepositoryProvider);
  return _TranslationNotifier(aiRepo);
});

// ── Translation Sheet ──────────────────────────────

/// Bottom sheet for translating selected text using AI.
///
/// Provides a language selector dropdown, streaming translation display,
/// and Replace/Insert Below actions.
class TranslationSheet extends ConsumerWidget {
  /// The text to translate.
  final String text;

  /// Callback to replace selected text with translated text.
  final void Function(String translated) onReplace;

  /// Callback to insert translated text below the current selection.
  final void Function(String translated) onInsertBelow;

  const TranslationSheet({
    super.key,
    required this.text,
    required this.onReplace,
    required this.onInsertBelow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(_translationProvider);

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
                    Icons.translate,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.aiTranslation,
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
            // Language selector + translate button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text(
                    l10n.translateTo,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LanguageSelector(
                      currentCode: state.targetLanguage,
                      onChanged: (code) {
                        ref
                            .read(_translationProvider.notifier)
                            .setTargetLanguage(code);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: state.isLoading
                        ? null
                        : () {
                            ref
                                .read(_translationProvider.notifier)
                                .translate(text);
                          },
                    child: Text(l10n.translate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Translated text result
            Expanded(
              child: _buildResult(context, ref, l10n, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResult(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    _TranslationState state,
  ) {
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
            ],
          ),
        ),
      );
    }

    if (state.isLoading && state.translatedText.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.translatedText.isEmpty) {
      return Center(
        child: Text(
          l10n.translationWillAppear,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  state.translatedText,
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
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: state.translatedText),
                        );
                        AppSnackBar.info(
                          context,
                          message: l10n.copiedToClipboard,
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.copy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        onReplace(state.translatedText);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.find_replace, size: 18),
                      label: Text(l10n.replace),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        onInsertBelow(state.translatedText);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.insertBelow),
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

// ── Language Selector Dropdown ─────────────────────

/// Dropdown button for selecting the target language.
class _LanguageSelector extends StatelessWidget {
  final String currentCode;
  final ValueChanged<String> onChanged;

  const _LanguageSelector({
    required this.currentCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: currentCode,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: _languages.map((lang) {
        return DropdownMenuItem(
          value: lang.code,
          child: Text(_localizedName(lang.nameKey)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  String _localizedName(String key) {
    switch (key) {
      case 'english':
        return 'English';
      case 'chinese':
        return 'Chinese';
      case 'japanese':
        return 'Japanese';
      case 'korean':
        return 'Korean';
      case 'french':
        return 'French';
      case 'german':
        return 'German';
      case 'spanish':
        return 'Spanish';
      default:
        return key;
    }
  }
}
