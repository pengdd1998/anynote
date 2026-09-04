import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/a11y_utils.dart';
import '../../../core/error/error.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../data/api_models.dart';
import '../data/settings_providers.dart';

class LLMConfigScreen extends ConsumerStatefulWidget {
  const LLMConfigScreen({super.key});

  @override
  ConsumerState<LLMConfigScreen> createState() => _LLMConfigScreenState();
}

class _LLMConfigScreenState extends ConsumerState<LLMConfigScreen> {
  // Built-in provider presets. 'id' is the provider identifier stored with
  // the local config; 'name' is the display label.
  // 'anthropic' configs are used OpenAI-compatibly: Anthropic exposes an
  // OpenAI-compatible chat endpoint under the same /v1 base URL.
  static const _presets = <Map<String, String>>[
    {'id': 'openai', 'name': 'OpenAI', 'baseUrl': 'https://api.openai.com/v1'},
    {
      'id': 'openai',
      'name': 'Xiaomi MiMo',
      'baseUrl': 'https://api.xiaomimimo.com/v1',
    },
    {'id': 'deepseek', 'name': 'DeepSeek', 'baseUrl': 'https://api.deepseek.com/v1'},
    {
      'id': 'qwen',
      'name': 'Qwen',
      'baseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    },
    {'id': 'anthropic', 'name': 'Anthropic', 'baseUrl': 'https://api.anthropic.com/v1'},
    {'id': 'custom', 'name': 'Custom', 'baseUrl': ''},
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final configsAsync = ref.watch(llmConfigsProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(l10n.llmConfigTitle)),
      body: configsAsync.when(
        data: (configs) {
          if (configs.isEmpty) {
            return Column(
              children: [
                _PrivacyNote(l10n: l10n),
                Expanded(
                  child: AppEmptyState(
                    icon: AppIcons.aiRobot,
                    title: l10n.noLLMConfigs,
                    subtitle: l10n.addLLMToEnableAI,
                    actionLabel: l10n.addProvider,
                    onAction: _showAddDialog,
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(llmConfigsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              // Index 0 is the privacy note; the rest are config cards.
              itemCount: configs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _PrivacyNote(l10n: l10n);
                final i = index - 1;
                final cfg = configs[i];
                final id = cfg.id;
                return StaggeredGroup(
                  staggerIndex: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LLMConfigCard(
                      cfg: cfg,
                      id: id,
                      l10n: l10n,
                      onTest: () => _testConfig(id),
                      onEdit: () => _showEditDialog(cfg),
                      onDelete: () => _confirmDelete(context, id, cfg.name),
                      onSetDefault: () => _setDefault(context, id),
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
                Icon(
                  ErrorDisplay.errorIcon(appError),
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(l10n.failedToLoadConfigs),
                const SizedBox(height: 8),
                Text(
                  ErrorDisplay.userMessage(appError, l10n),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
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
      floatingActionButton: A11yUtils.labeledButton(
        label: l10n.addProvider,
        child: FloatingActionButton(
          onPressed: _showAddDialog,
          child: const Icon(AppIcons.add),
        ),
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
        (p) => p['id'] == provider,
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
                A11yUtils.labeledTextField(
                  label: l10n.name,
                  child: TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: l10n.name),
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedProvider,
                  decoration: InputDecoration(labelText: l10n.provider),
                  items: _presets
                      .map(
                        (p) => DropdownMenuItem(
                          value: p['name'],
                          child: Text(p['name']!),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() => selectedProvider = v!);
                    onProviderChanged(v!);
                  },
                ),
                const SizedBox(height: 12),
                A11yUtils.labeledTextField(
                  label: l10n.baseUrl,
                  child: TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(labelText: l10n.baseUrl),
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                  ),
                ),
                const SizedBox(height: 12),
                _ApiKeyField(controller: keyCtrl, label: l10n.apiKey),
                const SizedBox(height: 12),
                A11yUtils.labeledTextField(
                  label: l10n.model,
                  child: TextField(
                    controller: modelCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.model,
                      hintText: l10n.modelHint,
                    ),
                    scrollPadding: const EdgeInsets.only(bottom: 120),
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
                String providerIdFor(String displayName) {
                  for (final p in _presets) {
                    if (p['name'] == displayName) return p['id']!;
                  }
                  return 'custom';
                }

                try {
                  // The first local config automatically becomes the default;
                  // direct AI calls route through the default config.
                  await ref.read(llmConfigsProvider.notifier).create({
                    'name': nameCtrl.text,
                    'provider': providerIdFor(selectedProvider),
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
  void _showEditDialog(LlmConfig cfg) {
    final l10n = AppLocalizations.of(context)!;
    final id = cfg.id;
    final nameCtrl = TextEditingController(text: cfg.name);
    final urlCtrl = TextEditingController(text: cfg.baseUrl ?? '');
    final keyCtrl = TextEditingController(); // Never pre-fill API key
    final modelCtrl = TextEditingController(text: cfg.model);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editLLMProvider),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              A11yUtils.labeledTextField(
                label: l10n.name,
                child: TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.name),
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                ),
              ),
              const SizedBox(height: 12),
              A11yUtils.labeledTextField(
                label: l10n.baseUrl,
                child: TextField(
                  controller: urlCtrl,
                  decoration: InputDecoration(labelText: l10n.baseUrl),
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                ),
              ),
              const SizedBox(height: 12),
              _ApiKeyField(controller: keyCtrl, label: l10n.newApiKeyHint),
              const SizedBox(height: 12),
              A11yUtils.labeledTextField(
                label: l10n.model,
                child: TextField(
                  controller: modelCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.model,
                    hintText: l10n.modelHint,
                  ),
                  scrollPadding: const EdgeInsets.only(bottom: 120),
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

  /// Mark [id] as the user's default LLM config. Direct AI calls route
  /// through the default local config; without one the shared LLM and its
  /// rate limits apply.
  Future<void> _setDefault(BuildContext context, String id) async {
    try {
      await ref.read(llmConfigsProvider.notifier).setDefault(id);
      if (mounted) {
        AppSnackBar.info(
          context,
          message:
              AppLocalizations.of(context)?.setAsDefault ?? 'Set as default',
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        ErrorDisplay.showSnackBar(context, appError);
      }
    }
  }

  /// Test an LLM config CLIENT-DIRECT: a tiny chat call against the config's
  /// own base URL. No server round trip; the API key never leaves the device
  /// except towards the provider itself.
  Future<void> _testConfig(String id) async {
    final l10n = AppLocalizations.of(context)!;
    AppSnackBar.info(context, message: l10n.testingConnection);
    try {
      await ref.read(llmConfigsProvider.notifier).test(id);
      if (mounted) {
        AppSnackBar.show(
          context,
          message: l10n.connectionSuccessful,
          type: SnackBarType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        // The call goes straight to the LLM provider, so the failure is
        // about the PROVIDER or the network — a generic "server error"
        // mapping would wrongly blame the AnyNote backend. Surface the
        // actual cause instead.
        String reason;
        if (e is DioException) {
          switch (e.type) {
            case DioExceptionType.connectionTimeout:
            case DioExceptionType.receiveTimeout:
            case DioExceptionType.sendTimeout:
              reason = l10n.llmProviderTimeout;
            case DioExceptionType.connectionError:
              reason = l10n.llmProviderUnreachable;
            case DioExceptionType.badResponse:
              final code = e.response?.statusCode ?? 0;
              reason = l10n.llmProviderHttpError(code);
            default:
              reason = ErrorDisplay.userMessage(ErrorMapper.map(e), l10n);
          }
        } else {
          reason = ErrorDisplay.userMessage(ErrorMapper.map(e), l10n);
        }
        AppSnackBar.show(
          context,
          message: l10n.connectionFailed(reason),
          type: SnackBarType.error,
        );
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
                if (!context.mounted) return;
                final appError = ErrorMapper.map(e);
                ErrorDisplay.showSnackBar(context, appError);
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
// Privacy note: local-only storage of LLM configs
// =============================================================================

class _PrivacyNote extends StatelessWidget {
  final AppLocalizations l10n;

  const _PrivacyNote({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.lock, size: 14, color: theme.hintColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.llmLocalOnlyNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
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
  final LlmConfig cfg;
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
    this.onSetDefault,
  });

  /// Called when the user taps "set as default" on a non-default config.
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SettingsGroup(
      children: [
        SettingsItem(
          icon: AppIcons.aiRobot,
          title: cfg.name,
          subtitle: '${cfg.provider} - ${cfg.model}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cfg.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.defaultLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              A11yUtils.labeledButton(
                label: l10n.testConnection,
                child: IconButton(
                  icon: const Icon(AppIcons.wifiTethering, size: 20),
                  tooltip: l10n.testConnection,
                  onPressed: id.isEmpty ? null : onTest,
                ),
              ),
              if (!cfg.isDefault && onSetDefault != null)
                A11yUtils.labeledButton(
                  label: l10n.setAsDefault,
                  child: IconButton(
                    icon: const Icon(AppIcons.starOutline, size: 20),
                    tooltip: l10n.setAsDefault,
                    onPressed: onSetDefault,
                  ),
                ),
              A11yUtils.labeledButton(
                label: l10n.delete,
                child: IconButton(
                  icon: const Icon(AppIcons.deleteOutline, size: 20),
                  tooltip: l10n.delete,
                  onPressed: id.isEmpty ? null : onDelete,
                ),
              ),
            ],
          ),
          onTap: onEdit,
        ),
      ],
    );
  }
}

/// API key input with a working show/hide toggle.
///
/// Self-contained StatefulWidget: the surrounding create/edit dialogs are
/// stateless `showDialog`s, so the obscure state has to live here — the
/// previous static suffix icon was decoration only and the field was
/// permanently obscured.
class _ApiKeyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const _ApiKeyField({required this.controller, required this.label});

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return A11yUtils.labeledTextField(
      label: widget.label,
      child: TextField(
        controller: widget.controller,
        obscureText: !_visible,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            icon: Icon(
              _visible ? AppIcons.visibility : AppIcons.visibilityOff,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
        scrollPadding: const EdgeInsets.only(bottom: 120),
      ),
    );
  }
}
