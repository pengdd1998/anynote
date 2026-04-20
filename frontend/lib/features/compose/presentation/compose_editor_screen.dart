import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/compose_providers.dart';

/// Full text editor with AI-generated content displayed via streaming.
///
/// Shows the draft text in an editable area with real-time streaming
/// display. Includes actions to adapt style, save as note (encrypted),
/// and navigate back to refine earlier stages.
class ComposeEditorScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ComposeEditorScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ComposeEditorScreen> createState() => _ComposeEditorScreenState();
}

class _ComposeEditorScreenState extends ConsumerState<ComposeEditorScreen> {
  late TextEditingController _editorController;
  final _scrollController = ScrollController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(composeSessionProvider);
      _editorController.text = session.draft;
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(composeSessionProvider);

    // Update editor when draft changes from streaming (but not when user is editing).
    if (session.isLoading && _editorController.text != session.draft) {
      _editorController.text = session.draft;
      // Auto-scroll to bottom during streaming.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        // TODO(localization): 'Editor' title should use l10n key
        title: const Text('Editor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Style adaptation button
          // TODO(localization): 'Adapt style for...' tooltip should use l10n key with param
          IconButton(
            icon: const Icon(Icons.style),
            tooltip: 'Adapt style for ${session.platformStyle}',
            onPressed: session.isLoading || session.draft.isEmpty
                ? null
                : () => _adaptStyle(ref),
          ),
          // Save button
          // TODO(localization): Save button tooltip should use l10n key (currently reuses 'Adapt style for...')
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Adapt style for ${session.platformStyle}',
            onPressed: session.isLoading || session.draft.isEmpty || _isSaving
                ? null
                : () => _saveAsNote(context, ref),
          ),
        ],
      ),
      body: _buildBody(context, session),
    );
  }

  Widget _buildBody(BuildContext context, ComposeSessionState session) {
    final l10n = AppLocalizations.of(context)!;
    // Error state
    if (session.error != null && session.draft.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                session.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.read(composeSessionProvider.notifier).clearError();
                  ref.read(composeSessionProvider.notifier).expandToDraft();
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Streaming indicator
        if (session.isLoading) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(77),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                // TODO(localization): 'AI is writing...' should use l10n key
                Text(
                  'AI is writing...',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // TODO(localization): 'N chars' should use l10n key with pluralization
                Text(
                  '${session.draft.length} chars',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        // Title area
        if (session.outline != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    session.outline!.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 20, endIndent: 20, height: 24),
        ],

        // Editor area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _editorController,
              scrollController: _scrollController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                border: InputBorder.none,
                // TODO(localization): 'Your composition will appear here...' hint should use l10n key
                hintText: 'Your composition will appear here...',
              ),
              onChanged: (text) {
                ref.read(composeSessionProvider.notifier).updateDraft(text);
              },
            ),
          ),
        ),

        // Bottom action bar
        SafeArea(
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Back to outline
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  // TODO(localization): 'Outline' button should use l10n key
                  label: const Text('Outline'),
                ),
                const SizedBox(width: 8),

                // Platform style chip
                if (session.platformStyle != 'generic')
                  Chip(
                    label: Text(session.platformStyle, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                  ),

                const Spacer(),

                // Word count
                // TODO(localization): 'N words' should use l10n key with pluralization
                Text(
                  '${_countWords(session.draft)} words',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(width: 12),

                // Save as note
                FilledButton.icon(
                  onPressed: session.draft.isEmpty || _isSaving || session.isLoading
                      ? null
                      : () => _saveAsNote(context, ref),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(l10n.saveAsNote),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _countWords(String text) {
    if (text.isEmpty) return 0;
    // Handle both space-separated and CJK text.
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words;
  }

  Future<void> _adaptStyle(WidgetRef ref) async {
    await ref.read(composeSessionProvider.notifier).adaptStyle();
  }

  Future<void> _saveAsNote(BuildContext context, WidgetRef ref) async {
    setState(() => _isSaving = true);

    try {
      final noteId = await ref.read(composeSessionProvider.notifier).saveDraftAsNote();

      if (!mounted) return;
      if (!context.mounted) return;

      if (noteId != null) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savedAsNote),
            // TODO(localization): 'View' SnackBar action label should use l10n key
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.push('/notes/$noteId'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          // TODO(localization): 'Failed to save note' should use l10n key
          const SnackBar(content: Text('Failed to save note')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
