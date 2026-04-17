import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PublishScreen extends ConsumerWidget {
  const PublishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = [
      {'name': 'Xiaohongshu', 'icon': Icons.camera_alt, 'connected': false},
      {'name': 'WeChat', 'icon': Icons.chat, 'connected': false},
      {'name': 'Zhihu', 'icon': Icons.question_answer, 'connected': false},
      {'name': 'Medium', 'icon': Icons.article, 'connected': false},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Publish')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connected Platforms', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...platforms.map((p) => Card(
                  child: ListTile(
                    leading: Icon(p['icon'] as IconData),
                    title: Text(p['name'] as String),
                    trailing: (p['connected'] as bool)
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : FilledButton.tonal(
                            onPressed: () => context.push('/settings/platforms'),
                            child: const Text('Connect'),
                          ),
                  ),
                )),
            const SizedBox(height: 24),
            Text('Recent Publications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.publish_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No publications yet', style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.push('/publish/history'),
                      child: const Text('View History'),
                    ),
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

class PublishHistoryScreen extends ConsumerWidget {
  const PublishHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publish History')),
      body: const Center(child: Text('No publish history')),
    );
  }
}
