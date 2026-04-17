import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ComposeScreen extends ConsumerWidget {
  const ComposeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Compose')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('AI-Powered Writing', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Select your notes and let AI help you create polished content for any platform.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () {
                        // TODO: Open note selector → start compose flow
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Start Composing'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Recent Compositions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No compositions yet', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClusterScreen extends ConsumerWidget {
  final String sessionId;
  const ClusterScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Note Clusters')),
      body: const Center(child: Text('Clustering in progress...')),
    );
  }
}

class OutlineScreen extends ConsumerWidget {
  final String sessionId;
  const OutlineScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outline')),
      body: const Center(child: Text('Generating outline...')),
    );
  }
}

class ComposeEditorScreen extends ConsumerWidget {
  final String sessionId;
  const ComposeEditorScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: const Center(child: Text('AI-powered editor')),
    );
  }
}
