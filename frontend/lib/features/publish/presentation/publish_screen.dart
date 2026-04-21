import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/error.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../data/publish_providers.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  // Static icon mapping for known platforms.
  static const _platformIcons = <String, IconData>{
    'xiaohongshu': Icons.camera_alt,
    'wechat': Icons.chat,
    'zhihu': Icons.question_answer,
    'medium': Icons.article,
  };

  String? _selectedPlatform;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platformsAsync = ref.watch(connectedPlatformsProvider);
    final historyAsync = ref.watch(publishHistoryProvider);
    final publishState = ref.watch(publishActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.publish),
        actions: const [SyncStatusWidget()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(connectedPlatformsProvider);
          ref.invalidate(publishHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connected platforms section
            _sectionHeader(context, l10n.connectedPlatforms),
            const SizedBox(height: 8),
            platformsAsync.when(
              data: (platforms) {
                if (platforms.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.share_outlined,
                              size: 36, color: Colors.grey.shade400,),
                          const SizedBox(height: 8),
                          Text(l10n.noPlatformsConnected),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () =>
                                context.push('/settings/platforms'),
                            child: Text(l10n.connectAPlatform),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: platforms.map((p) {
                    final name =
                        p['name']?.toString() ?? p['platform']?.toString() ?? l10n.unknown;
                    final platformKey =
                        p['key']?.toString() ?? name.toLowerCase();
                    final icon = _platformIcons[platformKey] ?? Icons.language;
                    final subtitle =
                        p['display_name']?.toString() ?? p['subtitle']?.toString() ?? '';
                    final isSelected = _selectedPlatform == platformKey;

                    return Card(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withAlpha(80)
                          : null,
                      child: Semantics(
                        button: true,
                        label: l10n.platformSemanticLabel(
                          name,
                          subtitle.isNotEmpty ? '. $subtitle' : '',
                          isSelected ? '. ${l10n.selectedLabel}' : '',
                        ),
                        child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(icon, size: 20),
                        ),
                        title: Text(name),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedPlatform = platformKey;
                          });
                        },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) {
                final appError = ErrorMapper.map(error);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(ErrorDisplay.errorIcon(appError),
                            size: 36, color: Colors.red,),
                        const SizedBox(height: 8),
                        Text(l10n.failedToLoadPlatforms),
                        const SizedBox(height: 4),
                        Text(ErrorDisplay.userMessage(appError),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey,),),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.invalidate(connectedPlatformsProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Publish form section
            _sectionHeader(context, l10n.publishContent),
            const SizedBox(height: 8),
            _buildPublishForm(context, publishState),

            const SizedBox(height: 24),

            // Recent publications section
            _sectionHeader(context, l10n.recentPublications),
            const SizedBox(height: 8),
            historyAsync.when(
              data: (history) {
                if (history.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.publish_outlined,
                              size: 48, color: Colors.grey.shade400,),
                          const SizedBox(height: 8),
                          Text(l10n.noPublicationsYet,
                              style:
                                  TextStyle(color: Colors.grey.shade500),),
                        ],
                      ),
                    ),
                  );
                }
                // Show the 3 most recent
                final recent = history.take(3).toList();
                return Column(
                  children: [
                    ...recent.map((item) => _buildHistoryTile(context, item)),
                    if (history.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                          onPressed: () =>
                              context.push('/publish/history'),
                          child: Text(
                              l10n.viewAll(history.length),),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) {
                final appError = ErrorMapper.map(error);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(ErrorDisplay.errorIcon(appError),
                            size: 36, color: Colors.red,),
                        const SizedBox(height: 8),
                        Text(ErrorDisplay.userMessage(appError)),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.invalidate(publishHistoryProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishForm(BuildContext context, PublishActionState state) {
    final l10n = AppLocalizations.of(context)!;
    final canPublish =
        _selectedPlatform != null && !state.isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.title,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: l10n.content,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: l10n.tagsCommaSeparated,
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: l10n.tagsHint,
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedPlatform == null)
              Text(
                l10n.selectPlatformToPublish,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  state.error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (state.result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16,),
                    const SizedBox(width: 4),
                    Text(
                      l10n.publishedStatus(state.result?['status'] ?? 'pending'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canPublish ? _handlePublish : null,
                child: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.publish),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(BuildContext context, Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context)!;
    final title = item['title']?.toString() ?? l10n.untitled;
    final platform = item['platform']?.toString() ?? l10n.unknown;
    final status = item['status']?.toString() ?? 'unknown';
    final createdAt = item['created_at']?.toString() ?? '';
    final platformURL = item['platform_url']?.toString() ?? '';

    final statusColor = switch (status) {
      'published' => Colors.green,
      'failed' => Colors.red,
      'publishing' => Colors.orange,
      'pending' => Colors.grey,
      _ => Colors.grey,
    };

    final statusIcon = switch (status) {
      'published' => Icons.check_circle,
      'failed' => Icons.error,
      'publishing' => Icons.sync,
      'pending' => Icons.schedule,
      _ => Icons.help_outline,
    };

    return Card(
      child: Semantics(
        button: platformURL.isNotEmpty,
        label: l10n.publishedSemanticLabel(
          title,
          platform,
          status,
          createdAt.isNotEmpty ? '. $createdAt' : '',
        ),
        child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$platform${createdAt.isNotEmpty ? ' - $createdAt' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: platformURL.isNotEmpty
            ? Semantics(
                button: true,
                label: l10n.openInBrowser,
                child: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () async {
                    final uri = Uri.parse(platformURL);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              )
            : Semantics(
                label: l10n.statusLabel(status),
                child: Chip(
                  label: Text(
                    status,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _handlePublish() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final tagsText = _tagsController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.titleAndContentRequired)),
      );
      return;
    }

    final tags = tagsText
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      await ref.read(publishActionProvider.notifier).publish(
            platform: _selectedPlatform!,
            title: title,
            content: content,
            tags: tags,
          );

      final state = ref.read(publishActionProvider);
      if (state.result != null && mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.publishRequestSubmitted)),
        );
        // Clear form on success
        _titleController.clear();
        _contentController.clear();
        _tagsController.clear();
        ref.invalidate(publishHistoryProvider);
        // Reset publish action after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) ref.read(publishActionProvider.notifier).reset();
        });
      } else if (state.error != null && mounted) {
        // PublishActionNotifier caught an error -- display it via ErrorDisplay.
        // Since the notifier stores a raw string, we map it generically.
        ErrorDisplay.showSnackBar(
          context,
          ValidationException(message: state.error!),
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        if (appError is AuthException) {
          ErrorDisplay.showErrorDialog(context, appError);
        } else {
          ErrorDisplay.showSnackBar(context, appError);
        }
      }
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
