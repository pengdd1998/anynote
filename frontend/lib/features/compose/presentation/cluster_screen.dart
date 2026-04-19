import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/compose_providers.dart';

/// Displays AI-generated note clusters and lets the user select which
/// clusters to include in the outline generation step.
class ClusterScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ClusterScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ClusterScreen> createState() => _ClusterScreenState();
}

class _ClusterScreenState extends ConsumerState<ClusterScreen> {
  bool _hasTriggeredClustering = false;

  @override
  void initState() {
    super.initState();
    // Trigger clustering on first build after the frame is complete.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerClustering();
    });
  }

  Future<void> _triggerClustering() async {
    if (_hasTriggeredClustering) return;
    _hasTriggeredClustering = true;
    await ref.read(composeSessionProvider.notifier).generateClusters();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(composeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Clusters'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(context, session),
    );
  }

  Widget _buildBody(BuildContext context, ComposeSessionState session) {
    final l10n = AppLocalizations.of(context)!;
    // Loading state
    if (session.isLoading && session.clusters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Clustering your notes...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'AI is analyzing ${session.selectedNoteIds.length} notes about "${session.topic}"',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Error state
    if (session.error != null && session.clusters.isEmpty) {
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
                  _hasTriggeredClustering = false;
                  _triggerClustering();
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    // Clusters ready
    return Column(
      children: [
        // Info header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI found ${session.clusters.length} themes. Select the ones to include.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Cluster list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: session.clusters.length,
            itemBuilder: (context, index) {
              final cluster = session.clusters[index];
              final isSelected = session.selectedClusterIndices.contains(index);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer.withAlpha(77)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                        : BorderSide(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(composeSessionProvider.notifier).toggleClusterSelection(index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isSelected,
                            onChanged: (v) {
                              ref.read(composeSessionProvider.notifier).toggleClusterSelection(index);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cluster.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cluster.theme,
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  cluster.summary,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${cluster.noteIndices.length} notes',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                Text(
                  '${session.selectedClusterIndices.length} clusters selected',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: session.selectedClusterIndices.isEmpty || session.isLoading
                      ? null
                      : () async {
                          await ref.read(composeSessionProvider.notifier).generateOutline();
                          if (mounted) {
                            context.push('/compose/outline/${widget.sessionId}');
                          }
                        },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Generate Outline'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
