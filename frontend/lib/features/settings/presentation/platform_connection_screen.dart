import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlatformConnectionScreen extends ConsumerStatefulWidget {
  const PlatformConnectionScreen({super.key});

  @override
  ConsumerState<PlatformConnectionScreen> createState() => _PlatformConnectionScreenState();
}

class _PlatformConnectionScreenState extends ConsumerState<PlatformConnectionScreen> {
  final _platforms = [
    {'name': 'Xiaohongshu', 'subtitle': '小红书', 'icon': Icons.camera_alt, 'connected': false},
    {'name': 'WeChat', 'subtitle': '微信公众号', 'icon': Icons.chat, 'connected': false},
    {'name': 'Zhihu', 'subtitle': '知乎', 'icon': Icons.question_answer, 'connected': false},
    {'name': 'Medium', 'subtitle': '', 'icon': Icons.article, 'connected': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Connections')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _platforms.map((p) {
          final connected = p['connected'] as bool;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(p['icon'] as IconData, size: 20),
              ),
              title: Text(p['name'] as String),
              subtitle: p['subtitle'] != null && (p['subtitle'] as String).isNotEmpty ? Text(p['subtitle'] as String) : null,
              trailing: connected
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () {}, child: const Text('Verify')),
                        TextButton(
                          onPressed: () => _confirmDisconnect(p['name'] as String),
                          child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    )
                  : FilledButton.tonal(
                      onPressed: () => _connect(p['name'] as String),
                      child: const Text('Connect'),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _connect(String platform) {
    if (platform == 'Xiaohongshu') {
      _showQRCodeDialog(platform);
    } else {
      // OAuth flow placeholder
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connecting to $platform...')));
    }
  }

  void _showQRCodeDialog(String platform) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200, height: 200,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Icon(Icons.qr_code_2, size: 120)),
            ),
            const SizedBox(height: 16),
            const Text('Open Xiaohongshu app and scan this QR code to login'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
  }

  void _confirmDisconnect(String platform) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect $platform'),
        content: Text('Are you sure you want to disconnect your $platform account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Disconnect')),
        ],
      ),
    );
  }
}
