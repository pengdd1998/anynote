import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../data/settings_providers.dart';

class LLMConfigScreen extends ConsumerStatefulWidget {
  const LLMConfigScreen({super.key});

  @override
  ConsumerState<LLMConfigScreen> createState() => _LLMConfigScreenState();
}

class _LLMConfigScreenState extends ConsumerState<LLMConfigScreen> {
  // Built-in provider presets. The actual provider list is also fetched from
  // the server via [llmProvidersProvider] and merged when available.
  static const _presets = <Map<String, String>>[
    {'name': 'OpenAI', 'baseUrl': 'https://api.openai.com/v1'},
    {'name': 'DeepSeek', 'baseUrl': 'https://api.deepseek.com/v1'},
    {
      'name': 'Qwen',
      'baseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    },
    {'name': 'Anthropic', 'baseUrl': 'https://api.anthropic.com/v1'},
    {'name': 'Custom', 'baseUrl': ''},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final configsAsync = ref.watch(llmConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.llmConfigTitle)),
      body: configsAsync.when(
        data: (configs) {
          if (configs.isEmpty) {
            return AppEmptyState(
              icon: Icons.smart_toy_outlined,
              title: l10n.noLLMConfigs,
              subtitle: l10n.addLLMToEnableAI,
              actionLabel: l10n.addProvider,
              onAction: _showAddDialog,
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(llmConfigsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: configs.length,
              itemBuilder: (context, index) {
                final cfg = configs[index];
                final id = cfg['id']?.toString() ?? '';
                return StaggeredGroup(
                  staggerIndex: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LLMConfigCard(
                      cfg: cfg,
                      id: id,
                      l10n: l10n,
                      onTest: () => _testConfig(id),
                      onEdit: () => _showEditDialog(cfg),
                      onDelete: () => _confirmDelete(context, id, cfg['name']?.toString() ?? ''),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final appError = ErrorMapper.map(error);
          final l10n = AppLocalizations.of(context)!;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ErrorDisplay.errorIcon(appError), size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(l10n.failedToLoadConfigs),
                const SizedBox(height: 8),
                Text(ErrorDisplay.userMessage(appError),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).disabledColor)),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(llmConfigsProvider.notifier).refresh(),
                  child: Text(l10n.retry),
                ),
              ],
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

  /// Show a dialog to add a new LLM config.
  void _showAddDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    String selectedProvider = 'OpenAI';

    // Pre-fill the base URL from presets when the provider changes.
    void onProviderChanged(String provider) {
      final preset = _presets.firstWhere(
        (p) => p['name'] == provider,
        orElse: () => {'name': provider, 'baseUrl': ''},
      );
      urlCtrl.text = preset['baseUrl'] ?? '';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.addLLMProvider),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.name),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedProvider,
                  decoration:
                      InputDecoration(labelText: l10n.provider),
                  items: _presets
                      .map((p) => DropdownMenuItem(
                            value: p['name'],
                            child: Text(p['name']!),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() => selectedProvider = v!);
                    onProviderChanged(v!);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration:
                      InputDecoration(labelText: l10n.baseUrl),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.apiKey,
                    suffixIcon: const Icon(Icons.visibility_off),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.model,
                    hintText: l10n.modelHint,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                try {
                  await ref.read(llmConfigsProvider.notifier).create({
                    'name': nameCtrl.text,
                    'provider': selectedProvider,
                    'base_url': urlCtrl.text,
                    'api_key': keyCtrl.text,
                    'model': modelCtrl.text,
                  });
                  nav.pop();
                } catch (e) {
                  nav.pop();
                  if (mounted) {
                    final appError = ErrorMapper.map(e);
                    ErrorDisplay.showSnackBar(context, appError);
                  }
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a dialog to edit an existing LLM config.
  void _showEditDialog(Map<String, dynamic> cfg) {
    final l10n = AppLocalizations.of(context)!;
    final id = cfg['id']?.toString() ?? '';
    final nameCtrl =
        TextEditingController(text: cfg['name']?.toString() ?? '');
    final urlCtrl =
        TextEditingController(text: cfg['base_url']?.toString() ?? '');
    final keyCtrl = TextEditingController(); // Never pre-fill API key
    final modelCtrl =
        TextEditingController(text: cfg['model']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editLLMProvider),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration:
                    InputDecoration(labelText: l10n.name),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration:
                    InputDecoration(labelText: l10n.baseUrl),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                decoration: InputDecoration(
                  labelText: l10n.newApiKeyHint,
                  suffixIcon: const Icon(Icons.visibility_off),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                decoration: InputDecoration(
                  labelText: l10n.model,
                  hintText: l10n.modelHint,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                final updateData = <String, dynamic>{
                  'name': nameCtrl.text,
                  'base_url': urlCtrl.text,
                  'model': modelCtrl.text,
                };
                // Only include API key if the user entered a new one.
                if (keyCtrl.text.isNotEmpty) {
                  updateData['api_key'] = keyCtrl.text;
                }
                await ref
                    .read(llmConfigsProvider.notifier)
                    .updateConfig(id, updateData);
                nav.pop();
              } catch (e) {
                nav.pop();
                if (mounted) {
                  final appError = ErrorMapper.map(e);
                  ErrorDisplay.showSnackBar(context, appError);
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  /// Test an LLM config by calling the test endpoint.
  Future<void> _testConfig(String id) async {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.testingConnection)),
    );
    try {
      final result =
          await ref.read(llmConfigsProvider.notifier).test(id);
      final success = result['success'] == true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? l10n.connectionSuccessful
                : l10n.connectionFailed(result['error']?.toString() ?? 'Unknown error')),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        ErrorDisplay.showSnackBar(context, appError);
      }
    }
  }

  /// Confirm and delete an LLM config.
  void _confirmDelete(BuildContext context, String id, String name) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfigQuestion(name)),
        content: Text(l10n.removeLLMConfigConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              try {
                await ref.read(llmConfigsProvider.notifier).delete(id);
                nav.pop();
              } catch (e) {
                nav.pop();
                if (mounted) {
                  final appError = ErrorMapper.map(e);
                  ErrorDisplay.showSnackBar(context, appError);
                }
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LLM Config card (used inside the staggered list)
// =============================================================================

class _LLMConfigCard extends StatelessWidget {
  final Map<String, dynamic> cfg;
  final String id;
  final AppLocalizations l10n;
  final VoidCallback onTest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LLMConfigCard({
    required this.cfg,
    required this.id,
    required this.l10n,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SettingsGroup(
      children: [
        SettingsItem(
          icon: Icons.smart_toy_outlined,
          title: cfg['name']?.toString() ?? '',
          subtitle: '${cfg['provider'] ?? ''} - ${cfg['model'] ?? ''}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cfg['is_default'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(l10n.defaultLabel,
                      style: TextStyle(fontSize: 11, color: colorScheme.onPrimaryContainer)),
                ),
              IconButton(
                icon: const Icon(Icons.wifi_tethering_outlined, size: 20),
                tooltip: l10n.testConnection,
                onPressed: id.isEmpty ? null : onTest,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: id.isEmpty ? null : onDelete,
              ),
            ],
          ),
          onTap: onEdit,
        ),
      ],
    );
  }
}
