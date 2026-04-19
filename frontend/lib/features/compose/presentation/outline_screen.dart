import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/compose_providers.dart';
import '../domain/outline_model.dart';

/// Displays the AI-generated outline with expandable sections.
///
/// Users can edit section headings, reorder sections via drag handles,
/// and toggle individual sections before expanding into a full draft.
class OutlineScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const OutlineScreen({super.key, required this.sessionId});

  @override
  ConsumerState<OutlineScreen> createState() => _OutlineScreenState();
}

class _OutlineScreenState extends ConsumerState<OutlineScreen> {
  final _expandedSections = <int>{};
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();

    // Initialize title controller from session state after first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(composeSessionProvider);
      if (session.outline != null) {
        _titleController.text = session.outline!.title;
      }
      // Expand all sections by default.
      if (session.outline != null) {
        setState(() {
          _expandedSections.addAll(
            List.generate(session.outline!.sections.length, (i) => i).toSet(),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(composeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outline'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (session.outline != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit title',
              onPressed: () => _showEditTitleDialog(context, session),
            ),
        ],
      ),
      body: _buildBody(context, session),
    );
  }

  Widget _buildBody(BuildContext context, ComposeSessionState session) {
    final l10n = AppLocalizations.of(context)!;
    // Loading state
    if (session.isLoading && session.outline == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Generating outline...'),
            const SizedBox(height: 8),
            Text(
              'Building structure from ${session.selectedClusterIndices.length} clusters',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Error state
    if (session.error != null && session.outline == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(session.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.read(composeSessionProvider.notifier).clearError();
                  ref.read(composeSessionProvider.notifier).generateOutline();
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final outline = session.outline;
    if (outline == null) {
      return const Center(child: Text('No outline generated.'));
    }

    // Ensure title controller stays in sync.
    if (_titleController.text != outline.title) {
      _titleController.text = outline.title;
    }

    return Column(
      children: [
        // Title display
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  outline.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Section count info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '${outline.sections.length} sections -- drag to reorder',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Sections list with reorderable support
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            buildDefaultDragHandles: false,
            itemCount: outline.sections.length,
            onReorder: (oldIndex, newIndex) {
              ref.read(composeSessionProvider.notifier).reorderSection(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final section = outline.sections[index];
              final isExpanded = _expandedSections.contains(index);

              return Card(
                key: ValueKey('section_$index'),
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      if (expanded) {
                        _expandedSections.add(index);
                      } else {
                        _expandedSections.remove(index);
                      }
                    });
                  },
                  tilePadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_handle, color: Colors.grey.shade400),
                  ),
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          section.heading,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // Points list
                    if (section.points.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Key Points:',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...section.points.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Icon(Icons.circle, size: 6, color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(point, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                    ],
                    if (section.sourceCluster != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'From cluster ${section.sourceCluster! + 1}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom action bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: session.isLoading
                      ? null
                      : () async {
                          await ref.read(composeSessionProvider.notifier).expandToDraft();
                          if (mounted) {
                            context.push('/compose/editor/${widget.sessionId}');
                          }
                        },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Expand to Draft'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showEditTitleDialog(BuildContext context, ComposeSessionState session) {
    final l10n = AppLocalizations.of(context)!;
    _titleController.text = session.outline?.title ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: _titleController,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = _titleController.text.trim();
              if (newTitle.isNotEmpty && session.outline != null) {
                ref.read(composeSessionProvider.notifier).updateOutline(
                  OutlineModel(
                    title: newTitle,
                    sections: session.outline!.sections,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
