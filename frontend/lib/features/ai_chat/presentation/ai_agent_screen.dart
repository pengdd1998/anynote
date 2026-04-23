import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/ai_agent_providers.dart';

/// AI Agent action screen.
/// Allows users to execute AI-powered autonomous actions on their notes.
class AIAgentScreen extends ConsumerWidget {
  const AIAgentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final agentState = ref.watch(aiAgentProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiAgent)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action selector.
            Text(
              l10n.selectAction,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.folder_outlined,
              title: l10n.organizeNotes,
              onTap: () => _executeAction(context, ref, 'organize'),
              enabled: !agentState.isLoading,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.summarize_outlined,
              title: l10n.summarizeNotes,
              onTap: () => _executeAction(context, ref, 'summarize'),
              enabled: !agentState.isLoading,
            ),
            const SizedBox(height: 8),
            _ActionCard(
              icon: Icons.add_circle_outline,
              title: l10n.createNote,
              onTap: () => _executeAction(context, ref, 'create_note'),
              enabled: !agentState.isLoading,
            ),

            const SizedBox(height: 24),

            // Result area.
            if (agentState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (agentState.error != null)
              _ResultCard(
                status: l10n.agentFailed,
                detail: agentState.error!,
                isSuccess: false,
              )
            else if (agentState.result != null)
              _ResultCard(
                status: l10n.agentComplete,
                detail: _formatResult(agentState.result!),
                isSuccess: true,
              ),
          ],
        ),
      ),
    );
  }

  void _executeAction(BuildContext context, WidgetRef ref, String action) {
    ref.read(aiAgentProvider.notifier).execute(action: action);
  }

  String _formatResult(Map<String, dynamic> result) {
    final parts = <String>[];
    result.forEach((key, value) {
      parts.add('$key: $value');
    });
    return parts.join('\n');
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String status;
  final String detail;
  final bool isSuccess;

  const _ResultCard({
    required this.status,
    required this.detail,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color:
          isSuccess ? colorScheme.primaryContainer : colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isSuccess
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSuccess
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
