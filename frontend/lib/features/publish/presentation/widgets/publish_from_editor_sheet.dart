import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../compose/domain/post_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error.dart';
import '../../../../core/theme/alpha_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notes/presentation/widgets/writing_assist_sheet.dart';
import '../../data/publish_providers.dart';
import '../../domain/publish_rules.dart';
import 'publish_problems_list.dart';

class PublishFromEditorSheet extends ConsumerStatefulWidget {
  final String title;
  final String content;
  final List<String> initialTags;

  /// Template selected upstream (e.g. in the AI compose flow). Applied to
  /// the writing-assist polish pass so platform copy keeps the template's
  /// structure and tone.
  final PostTemplate? template;

  /// The platform the draft was written for (the one chosen in AI compose),
  /// selected when the sheet opens. It counts only if that platform is
  /// connected; otherwise the sheet opens with nothing selected.
  final String? initialPlatform;

  const PublishFromEditorSheet({
    super.key,
    required this.title,
    required this.content,
    this.initialTags = const [],
    this.template,
    this.initialPlatform,
  });

  @override
  ConsumerState<PublishFromEditorSheet> createState() =>
      _PublishFromEditorSheetState();
}

class _PublishFromEditorSheetState
    extends ConsumerState<PublishFromEditorSheet> {
  static const _platformIcons = <String, IconData>{
    'xiaohongshu': AppIcons.camera,
    'wechat': AppIcons.chat,
    'zhihu': AppIcons.questionAnswer,
    'medium': AppIcons.article,
  };

  late final _titleController = TextEditingController(text: widget.title);
  late final _contentController = TextEditingController(text: widget.content);
  late final _tagsController = TextEditingController(
    text: widget.initialTags.join(', '),
  );
  late String? _selectedPlatform = widget.initialPlatform;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleController,
      _contentController,
      _tagsController,
    ]) {
      controller.addListener(_onDraftChanged);
    }
    // A draft arrives with a title and a body already, so say right away
    // what the platform's rules think of it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleValidation();
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _titleController,
      _contentController,
      _tagsController,
    ]) {
      controller.removeListener(_onDraftChanged);
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _tags => _tagsController.text
      .trim()
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  /// The id a platform is published under, as the server's list names it.
  static String _platformKey(Map<String, dynamic> p) =>
      p['key']?.toString() ??
      (p['name']?.toString() ?? p['platform']?.toString() ?? '').toLowerCase();

  /// The chosen platform once the connected ones are known, and only if it
  /// is one of them: a draft composed for a platform the user has not
  /// connected opens with nothing selected rather than offering a publish
  /// that cannot work.
  String? get _platform {
    final selected = _selectedPlatform;
    if (selected == null) return null;
    final connected = ref.read(connectedPlatformsProvider).valueOrNull;
    if (connected == null) return null;
    return connected.any((p) => _platformKey(p) == selected) ? selected : null;
  }

  /// Redraws the length counters and asks the server to re-check the draft.
  void _onDraftChanged() {
    setState(() {});
    // Whatever a rejected publish said was about the previous draft.
    if (ref.read(publishActionProvider).error != null) {
      ref.read(publishActionProvider.notifier).reset();
    }
    _scheduleValidation();
  }

  /// Nothing to check before a platform is chosen, and an empty title or
  /// body is already reported when the user tries to publish.
  void _scheduleValidation() {
    final validator = ref.read(publishValidationProvider.notifier);
    final platform = _platform;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (platform == null || title.isEmpty || content.isEmpty) {
      validator.reset();
      return;
    }
    validator.check(
      platformId: platform,
      title: title,
      content: content,
      tags: _tags,
    );
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
        template: widget.template,
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

    if (_platform == null) {
      AppSnackBar.error(context, message: l10n.selectPlatformFirst);
      return;
    }

    await ref.read(publishActionProvider.notifier).publish(
          platform: _platform!,
          title: title,
          content: content,
          tags: _tags,
        );

    if (!mounted) return;
    final state = ref.read(publishActionProvider);
    if (state.result != null) {
      AppSnackBar.info(context, message: l10n.notePublishedSuccess);
      ref.invalidate(publishHistoryProvider);
      Navigator.pop(context);
    } else if (state.error != null && state.problems.isEmpty) {
      // With field-level problems the list in the sheet explains everything;
      // only a rejection the server could not break down needs a snackbar.
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
    final validation = ref.watch(publishValidationProvider);
    final guidesAsync = ref.watch(platformGuidesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // A platform counts as chosen only once the connected ones are known, so
    // that is the earliest moment a preselected one can be checked.
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      connectedPlatformsProvider,
      (previous, next) {
        if (previous?.hasValue != true && next.hasValue) {
          _scheduleValidation();
        }
      },
    );

    // The limits of the selected platform, from the server's rules.
    final platform = _platform;
    final guide = platform == null
        ? null
        : guidesAsync.whenOrNull(
            data: (guides) => guideFor(guides, platform),
          );
    final titleLength = PlatformGuide.lengthOf(_titleController.text.trim());
    final contentLength =
        PlatformGuide.lengthOf(_contentController.text.trim());
    // Judged here rather than by the server so the button reacts as soon as
    // the user types, not a round trip later.
    final overLimit = guide != null &&
        (titleLength > guide.titleMax ||
            contentLength > guide.contentMax ||
            _tags.length > guide.maxTags);
    // A rejected publish explains itself until the draft changes; from then
    // on the live check is what describes what is on screen.
    final rejected =
        publishState.problems.isNotEmpty || publishState.warnings.isNotEmpty;
    final blocking = rejected ? publishState.problems : validation.blocking;
    final advisory = rejected ? publishState.warnings : validation.advisory;

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
                    icon: const Icon(AppIcons.magicWand),
                    tooltip: l10n.polishContent,
                    onPressed: _showPolishSheet,
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    TextField(
                      controller: _titleController,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: InputDecoration(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.title),
                            if (guide != null) ...[
                              const SizedBox(width: 8),
                              LengthCounter(
                                  length: titleLength, max: guide.titleMax),
                            ],
                          ],
                        ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Content
                    TextField(
                      controller: _contentController,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: InputDecoration(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.content),
                            if (guide != null) ...[
                              const SizedBox(width: 8),
                              LengthCounter(
                                  length: contentLength, max: guide.contentMax),
                            ],
                          ],
                        ),
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),

                    // Tags
                    TextField(
                      controller: _tagsController,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
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
                                    AppIcons.share,
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
                            final platformKey = _platformKey(p);
                            final icon = _platformIcons[platformKey] ??
                                AppIcons.language;
                            final subtitle = p['display_name']?.toString() ??
                                p['subtitle']?.toString() ??
                                '';
                            final isSelected = _selectedPlatform == platformKey;

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
                                subtitle:
                                    subtitle.isNotEmpty ? Text(subtitle) : null,
                                trailing: isSelected
                                    ? const Icon(
                                        AppIcons.checkCircle,
                                        color: AppColors.success,
                                      )
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedPlatform = platformKey;
                                  });
                                  _scheduleValidation();
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
                                  onPressed: () => ref
                                      .invalidate(connectedPlatformsProvider),
                                  child: Text(l10n.retry),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // What is wrong with the draft: live while writing, or
                    // the reason a submit was rejected.
                    if (guide != null || rejected)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PublishProblemsList(
                          blocking: blocking,
                          advisory: advisory,
                          checking: validation.isChecking,
                        ),
                      ),
                    // A rejection the server could not break down by field.
                    if (publishState.error != null &&
                        publishState.problems.isEmpty &&
                        !rejected)
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
                        // Over the platform's limits, or the server has
                        // said the draft cannot go out as it stands.
                        onPressed: publishState.isLoading ||
                                overLimit ||
                                validation.blocking.isNotEmpty
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
