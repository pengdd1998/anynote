import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account section
          _sectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Email'),
            subtitle: const Text('user@example.com'),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Plan'),
            subtitle: const Text('Free'),
            trailing: FilledButton.tonal(onPressed: () {}, child: const Text('Upgrade')),
          ),

          const Divider(),

          // AI section
          _sectionHeader(context, 'AI'),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('LLM Configuration'),
            subtitle: const Text('Configure your AI providers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/llm'),
          ),
          ListTile(
            leading: const Icon(Icons.data_usage_outlined),
            title: const Text('AI Quota'),
            subtitle: const Text('50/50 requests today'),
          ),

          const Divider(),

          // Publishing section
          _sectionHeader(context, 'Publishing'),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Platform Connections'),
            subtitle: const Text('Manage connected platforms'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/platforms'),
          ),

          const Divider(),

          // Security section
          _sectionHeader(context, 'Security & Privacy'),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Encryption Settings'),
            subtitle: const Text('E2E encryption active'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/security'),
          ),

          const Divider(),

          // Sync section
          _sectionHeader(context, 'Sync'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Sync Status'),
            subtitle: const Text('Last synced: Never'),
            trailing: OutlinedButton(onPressed: () {}, child: const Text('Sync Now')),
          ),

          const Divider(),

          // About section
          _sectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('0.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () {},
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
    );
  }
}
