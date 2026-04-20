import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/error/error.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../data/compose_providers.dart';

/// Home screen for the AI Compose feature.
///
/// Displays a hero card with a "Start Composing" action that opens a
/// bottom sheet for note selection, plus a list of recent compositions.
class ComposeScreen extends ConsumerWidget {
  const ComposeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notesAsync = ref.watch(notesForSelectionProvider);
    final historyAsync = ref.watch(generatedContentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiCompose),
        actions: const [SyncStatusWidget()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.aiPoweredWriting,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.aiComposeDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    PressableScale(
                      onPressed: () => _showNoteSelector(context, ref, notesAsync),
                      child: Semantics(
                        button: true,
                        label: l10n.startComposing,
                        child: FilledButton.icon(
                          onPressed: () => _showNoteSelector(context, ref, notesAsync),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.startComposing),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent compositions header
            Text(
              l10n.recentCompositions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Recent compositions list
            Expanded(
              child: historyAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noCompositionsYet,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final title = item.plainBody != null && item.plainBody!.length > 80
                          ? '${item.plainBody!.substring(0, 80)}...'
                          // TODO(localization): Use l10n.untitled instead of hardcoded 'Untitled'
                          : item.plainBody ?? 'Untitled';
                      final time = _formatTime(item.updatedAt);
                      final platform = item.platformStyle;

                      return Card(
                        child: Semantics(
                          button: true,
                          // TODO(localization): Localize this semantic label composition string
                          label: 'Composition: $title. $time${platform != 'generic' ? '. Platform: $platform' : ''}',
                          child: ListTile(
                          leading: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              if (platform != 'generic')
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text(platform, style: const TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                          onTap: () => _showContentPreview(context, ref, item),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 3,
                  shrinkWrap: true,
                  itemBuilder: (_, __) => const AppLoadingCard(),
                ),
                error: (err, _) {
                  final appError = ErrorMapper.map(err);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ErrorDisplay.errorIcon(appError),
                            size: 36, color: Colors.grey.shade400,),
                        const SizedBox(height: 8),
                        Text(
                          ErrorDisplay.userMessage(appError),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a bottom sheet for selecting notes and entering a topic.
  void _showNoteSelector(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> notesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NoteSelectorSheet(notesAsync: notesAsync),
    );
  }

  /// Shows a preview of the generated content with copy and save-as-note actions.
  void _showContentPreview(BuildContext context, WidgetRef ref, dynamic item) {
    final content = item.plainBody as String? ?? '';
    final platform = item.platformStyle as String? ?? 'generic';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ContentPreviewSheet(
        content: content,
        platform: platform,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    // TODO(localization): Use AppLocalizations for relative time strings
    // instead of hardcoded English. The notes_list_screen.dart has the
    // correct pattern: l10n.justNow, l10n.minutesAgo(n), etc.
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}

/// Bottom sheet for selecting notes and providing a topic before starting
/// the AI composition flow.
class _NoteSelectorSheet extends ConsumerStatefulWidget {
  final AsyncValue<List<dynamic>> notesAsync;

  const _NoteSelectorSheet({required this.notesAsync});

  @override
  ConsumerState<_NoteSelectorSheet> createState() => _NoteSelectorSheetState();
}

class _NoteSelectorSheetState extends ConsumerState<_NoteSelectorSheet> {
  final _topicController = TextEditingController();
  String _platformStyle = 'generic';
  final Set<String> _selectedIds = {};

  // TODO(localization): Platform display names should be localized via .arb files.
  // The tuple values (second element) are hardcoded English labels shown in the UI.
  static const _platformOptions = [
    ('generic', 'Generic'),
    ('xhs', 'XHS'),
    ('twitter', 'Twitter'),
    ('blog', 'Blog'),
    ('linkedin', 'LinkedIn'),
  ];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
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
                  Text(l10n.newComposition, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Topic field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: l10n.topicOrTheme,
                  hintText: l10n.topicHint,
                  prefixIcon: const Icon(Icons.lightbulb_outline),
                ),
                onChanged: (v) => ref.read(composeSessionProvider.notifier).setTopic(v),
              ),
            ),

            // Platform selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _platformStyle,
                decoration: InputDecoration(
                  labelText: l10n.targetPlatform,
                  prefixIcon: const Icon(Icons.share_outlined),
                ),
                items: _platformOptions
                    .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _platformStyle = v);
                    ref.read(composeSessionProvider.notifier).setPlatformStyle(v);
                  }
                },
              ),
            ),

            // Note list label
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(l10n.selectNotes, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 8),
                  Text(
                    l10n.selectedCount(_selectedIds.length),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Note list
            Expanded(
              child: widget.notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return Center(
                      child: Text(l10n.noNotesAvailableCreate, textAlign: TextAlign.center),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      // TODO(localization): Use l10n.untitled instead of hardcoded 'Untitled'
                      final title = note.plainTitle ?? 'Untitled';
                      final preview = note.plainContent != null && note.plainContent!.length > 60
                          ? '${note.plainContent!.substring(0, 60)}...'
                          : note.plainContent ?? '';
                      final isSelected = _selectedIds.contains(note.id);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(note.id);
                            } else {
                              _selectedIds.remove(note.id);
                            }
                          });
                          ref.read(composeSessionProvider.notifier).toggleNoteSelection(
                            note.id,
                            note.plainContent ?? '',
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 3,
                  shrinkWrap: true,
                  itemBuilder: (_, __) => const AppLoadingCard(),
                ),
                error: (err, _) {
                  final appError = ErrorMapper.map(err);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(ErrorDisplay.errorIcon(appError),
                            size: 36, color: Colors.grey.shade400,),
                        const SizedBox(height: 8),
                        Text(
                          ErrorDisplay.userMessage(appError),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Start button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty || _topicController.text.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            final sessionId = ref.read(startComposeSessionProvider)();
                            context.push('/compose/cluster/$sessionId');
                          },
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.startComposing),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet that displays generated content with copy and save-as-note actions.
class _ContentPreviewSheet extends ConsumerStatefulWidget {
  final String content;
  final String platform;

  const _ContentPreviewSheet({
    required this.content,
    required this.platform,
  });

  @override
  ConsumerState<_ContentPreviewSheet> createState() => _ContentPreviewSheetState();
}

class _ContentPreviewSheetState extends ConsumerState<_ContentPreviewSheet> {
  bool _isSaving = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.copiedToClipboard)),
      );
    }
  }

  Future<void> _saveAsNote() async {
    if (widget.content.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final noteId = const Uuid().v4();

      String encryptedContent;
      String? encryptedTitle;

      if (crypto.isUnlocked) {
        encryptedContent = await crypto.encryptForItem(noteId, widget.content);
        final title = widget.content.length > 50
            ? widget.content.substring(0, 50)
            : widget.content;
        encryptedTitle = await crypto.encryptForItem(noteId, title);
      } else {
        encryptedContent = widget.content;
        encryptedTitle = widget.content.length > 50
            ? widget.content.substring(0, 50)
            : widget.content;
      }

      await db.notesDao.createNote(
        id: noteId,
        encryptedContent: encryptedContent,
        encryptedTitle: encryptedTitle,
        plainContent: widget.content,
        plainTitle: widget.content.length > 50
            ? widget.content.substring(0, 50)
            : widget.content,
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.savedAsNote)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorDisplay.userMessage(appError))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Text(
                  l10n.contentPreview,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (widget.platform != 'generic')
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(widget.platform, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content display
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.content.isEmpty ? l10n.noContent : widget.content,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.copy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveAsNote,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.saveAsNote),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
