import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error.dart';
import '../../../../core/theme/alpha_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notes/presentation/widgets/writing_assist_sheet.dart';
import '../../data/publish_providers.dart';

class PublishFromEditorSheet extends ConsumerStatefulWidget {
  final String title;
  final String content;
  final List<String> initialTags;

  const PublishFromEditorSheet({
    super.key,
    required this.title,
    required this.content,
    this.initialTags = const [],
  });

  @override
  ConsumerState<PublishFromEditorSheet> createState() =>
      _PublishFromEditorSheetState();
}

class _PublishFromEditorSheetState
    extends ConsumerState<PublishFromEditorSheet> {
  static const _platformIcons = <String, IconData>{
    'xiaohongshu': Icons.camera_alt,
    'wechat': Icons.chat,
    'zhihu': Icons.question_answer,
    'medium': Icons.article,
  };

  late final _titleController = TextEditingController(text: widget.title);
  late final _contentController = TextEditingController(text: widget.content);
  late final _tagsController = TextEditingController(
    text: widget.initialTags.join(', '),
  );
  String? _selectedPlatform;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _showPolishSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WritingAssistSheet(
        originalText: _contentController.text,
        onAccept: (corrected) {
          setState(() {
            _contentController.text = corrected;
          });
        },
      ),
    );
  }

  Future<void> _handlePublish() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      AppSnackBar.error(context, message: l10n.titleAndContentRequired);
      return;
    }

    if (_selectedPlatform == null) {
      AppSnackBar.error(context, message: l10n.selectPlatformFirst);
      return;
    }

    final tags = _tagsController.text
        .trim()
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    await ref.read(publishActionProvider.notifier).publish(
          platform: _selectedPlatform!,
          title: title,
          content: content,
          tags: tags,
        );

    if (!mounted) return;
    final state = ref.read(publishActionProvider);
    if (state.result != null) {
      AppSnackBar.info(context, message: l10n.notePublishedSuccess);
      ref.invalidate(publishHistoryProvider);
      Navigator.pop(context);
    } else if (state.error != null) {
      ErrorDisplay.showSnackBar(
        context,
        ValidationException(message: state.error!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platformsAsync = ref.watch(connectedPlatformsProvider);
    final publishState = ref.watch(publishActionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withAlpha(
                    (0.3 * 255).round(),
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Text(
                    l10n.publishToPlatform,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    tooltip: l10n.polishContent,
                    onPressed: _showPolishSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.title,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Content
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

                    // Tags
                    TextField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        labelText: l10n.tagsCommaSeparated,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        hintText: l10n.tagsHint,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Platform selection
                    Text(
                      l10n.connectedPlatforms,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    platformsAsync.when(
                      data: (platforms) {
                        if (platforms.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.share_outlined,
                                    size: 36,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(l10n.noPlatformsConnected),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.push('/settings/platforms');
                                    },
                                    child: Text(l10n.connectAPlatform),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: platforms.map((p) {
                            final name = p['name']?.toString() ??
                                p['platform']?.toString() ??
                                l10n.unknown;
                            final platformKey =
                                p['key']?.toString() ?? name.toLowerCase();
                            final icon =
                                _platformIcons[platformKey] ?? Icons.language;
                            final subtitle =
                                p['display_name']?.toString() ??
                                    p['subtitle']?.toString() ??
                                    '';
                            final isSelected =
                                _selectedPlatform == platformKey;

                            return Card(
                              color: isSelected
                                  ? colorScheme.primaryContainer.withAlpha(
                                      AppAlpha.bold,
                                    )
                                  : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(icon, size: 20),
                                ),
                                title: Text(name),
                                subtitle: subtitle.isNotEmpty
                                    ? Text(subtitle)
                                    : null,
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: AppColors.success,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedPlatform = platformKey;
                                  });
                                },
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
                                Icon(
                                  ErrorDisplay.errorIcon(appError),
                                  size: 36,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(height: 8),
                                Text(l10n.failedToLoadPlatforms),
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
                    const SizedBox(height: 16),

                    // Error display
                    if (publishState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          publishState.error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.error,
                          ),
                        ),
                      ),

                    // Publish button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: publishState.isLoading
                            ? null
                            : _handlePublish,
                        child: publishState.isLoading
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
            ),
          ],
        );
      },
    );
  }
}
