import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LLMConfigScreen extends ConsumerStatefulWidget {
  const LLMConfigScreen({super.key});

  @override
  ConsumerState<LLMConfigScreen> createState() => _LLMConfigScreenState();
}

class _LLMConfigScreenState extends ConsumerState<LLMConfigScreen> {
  final _configs = <Map<String, dynamic>>[];
  final _providers = [
    {'name': 'OpenAI', 'baseUrl': 'https://api.openai.com/v1'},
    {'name': 'DeepSeek', 'baseUrl': 'https://api.deepseek.com/v1'},
    {'name': 'Qwen', 'baseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1'},
    {'name': 'Anthropic', 'baseUrl': 'https://api.anthropic.com/v1'},
    {'name': 'Custom', 'baseUrl': ''},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LLM Configuration')),
      body: _configs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No LLM providers configured'),
                  const SizedBox(height: 8),
                  const Text('Add your own LLM API key or use the shared provider', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _configs.length,
              itemBuilder: (context, index) {
                final cfg = _configs[index];
                return Card(
                  child: ListTile(
                    title: Text(cfg['name'] ?? ''),
                    subtitle: Text('${cfg['provider']} - ${cfg['model']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cfg['is_default'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                            child: const Text('Default', style: TextStyle(fontSize: 11)),
                          ),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    String selectedProvider = 'OpenAI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add LLM Provider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedProvider,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: _providers.map((p) => DropdownMenuItem(value: p['name'], child: Text(p['name']!))).toList(),
                  onChanged: (v) {
                    setDialogState(() => selectedProvider = v!);
                    final provider = _providers.firstWhere((p) => p['name'] == v);
                    urlCtrl.text = provider['baseUrl'] ?? '';
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Base URL')),
                const SizedBox(height: 12),
                TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'API Key', suffixIcon: Icon(Icons.visibility_off)), obscureText: true),
                const SizedBox(height: 12),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Model', hintText: 'e.g., gpt-4o')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _configs.add({
                    'name': nameCtrl.text,
                    'provider': selectedProvider,
                    'base_url': urlCtrl.text,
                    'model': modelCtrl.text,
                    'is_default': _configs.isEmpty,
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
