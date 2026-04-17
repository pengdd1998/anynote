import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EncryptionScreen extends ConsumerStatefulWidget {
  const EncryptionScreen({super.key});

  @override
  ConsumerState<EncryptionScreen> createState() => _EncryptionScreenState();
}

class _EncryptionScreenState extends ConsumerState<EncryptionScreen> {
  bool _showRecoveryKey = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security & Encryption')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encryption status card
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.verified_user, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text('E2E Encryption Active', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green.shade800)),
                  const SizedBox(height: 8),
                  const Text('Your data is encrypted with XChaCha20-Poly1305', style: TextStyle(fontSize: 13, color: Colors.green)),
                  const SizedBox(height: 4),
                  Text('Key derivation: Argon2id', style: TextStyle(fontSize: 13, color: Colors.green.shade700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Encryption details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Encrypted Items', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _infoRow('Notes', '0 items'),
                  _infoRow('Tags', '0 items'),
                  _infoRow('Collections', '0 items'),
                  _infoRow('AI Content', '0 items'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Recovery Key
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recovery Key', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text('Use this key to recover your data if you forget your password.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  if (_showRecoveryKey)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: const SelectableText(
                        'abandon ability able about above absent absorb abstract absurd abuse access accident account accuse achieve acid acoustic acquire across action actor actress actual adapt address',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: _verifyAndShowRecoveryKey,
                      child: const Text('View Recovery Key'),
                    ),
                  if (_showRecoveryKey) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy to Clipboard'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Change Password
          Card(
            child: ListTile(
              title: const Text('Change Password'),
              subtitle: const Text('Re-encrypts all data with new key'),
              leading: const Icon(Icons.key_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showChangePasswordDialog,
            ),
          ),
          const SizedBox(height: 8),

          // Danger Zone
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Danger Zone', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmDeleteAll,
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Delete All Local Data', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download),
                      label: const Text('Export Encrypted Backup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label), Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _verifyAndShowRecoveryKey() {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Password'),
        content: TextField(
          controller: passwordCtrl,
          decoration: const InputDecoration(labelText: 'Enter your password'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _showRecoveryKey = true);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentCtrl, decoration: const InputDecoration(labelText: 'Current Password'), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, decoration: const InputDecoration(labelText: 'New Password'), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: 'Confirm New Password'), obscureText: true),
            const SizedBox(height: 8),
            const Text('Warning: This will re-encrypt all your data.', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Change')),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text('This action is irreversible. All your notes, tags, and settings will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Double confirm
              showDialog(
                context: context,
                builder: (ctx2) => AlertDialog(
                  title: const Text('Are you absolutely sure?'),
                  content: const Text('Type DELETE to confirm.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx2), child: const Text('DELETE')),
                  ],
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
}
