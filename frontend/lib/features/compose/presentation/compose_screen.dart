import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/error/error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../routing/app_router.dart';
import '../data/compose_providers.dart';

/// Guard to prevent multiple bottom sheet invocations on rapid tap.
final _noteSelectorShowingProvider = StateProvider<bool>((ref) => false);

/// Home screen for the AI Compose feature.
///
/// Displays a hero card with a "Start Composing" action that opens a
/// bottom sheet for note selection, plus a list of recent compositions.
class ComposeScreen extends ConsumerWidget {
  const ComposeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notesAsync = ref.watch(notesForSelectionProvider);
    final historyAsync = ref.watch(generatedContentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiCompose),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [SyncStatusWidget()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.s4,
          AppSpacing.md,
          96,
        ),
        children: [
          // Hero card
          _buildHeroCard(context, ref, notesAsync, l10n, isDark),
          const SizedBox(height: AppSpacing.lg),

          // Recent compositions header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Text(
              l10n.recentCompositions,
              style: AppTextStyles.title,
            ),
          ),

          // Recent compositions list
          historyAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return _buildEmptyState(l10n, isDark);
              }
              return Column(
                children: items.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: _buildSessionCard(
                      context,
                      ref,
                      entry.value,
                      entry.key,
                      l10n,
                      isDark,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.s8),
                  child: AppLoadingCard(),
                ),
              ),
            ),
            error: (err, _) {
              final appError = ErrorMapper.map(err);
              return _buildErrorState(appError, l10n, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> notesAsync,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _showNoteSelector(context, ref, notesAsync),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    AppColors.primary.withAlpha(40),
                    AppColors.accentLavender.withAlpha(30),
                  ]
                : [
                    AppColors.primary.withAlpha(20),
                    AppColors.accentLavenderBg,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder.withAlpha(60)
                : AppColors.lightBorder.withAlpha(80),
            width: 0.5,
          ),
          boxShadow: AppShadows.mdOf(Theme.of(context).brightness),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.startComposing,
                        style: AppTextStyles.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.selectNotes,
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
    int index,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final title = item.plainBody != null && item.plainBody!.length > 80
        ? '${item.plainBody!.substring(0, 80)}...'
        : item.plainBody ?? l10n.untitled;
    final time = _formatTime(context, item.updatedAt);
    final platform = item.platformStyle ?? 'generic';

    // Warm pastel cycling for session cards
    const accentBgs = [
      AppColors.accentLavenderBg,
      AppColors.accentYellowBg,
      AppColors.accentMintBg,
      AppColors.accentPeachBg,
    ];
    const accentIcons = [
      AppColors.accentLavenderText,
      AppColors.accentYellowText,
      AppColors.accentMintText,
      AppColors.accentPeachText,
    ];

    final accentBg = accentBgs[index % accentBgs.length];
    final accentIcon = accentIcons[index % accentIcons.length];

    return GestureDetector(
      onTap: () => _showContentPreview(context, ref, item),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.smOf(Theme.of(context).brightness),
        ),
        child: Row(
          children: [
            // Numbered badge with accent
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accentIcon,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            // Content + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (platform != 'generic') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            platform,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                      ],
                      Text(
                        time,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentLavenderBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.article_outlined,
              size: 28,
              color: AppColors.accentLavenderText,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            l10n.noCompositionsYet,
            style: AppTextStyles.body.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    dynamic appError,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(
            ErrorDisplay.errorIcon(appError),
            size: 36,
            color: AppColors.error.withAlpha(150),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            ErrorDisplay.userMessage(appError, l10n),
            style: AppTextStyles.body.copyWith(
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showNoteSelector(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> notesAsync,
  ) {
    if (ref.read(_noteSelectorShowingProvider)) return;
    ref.read(_noteSelectorShowingProvider.notifier).state = true;

    ref.read(composeSessionProvider.notifier).resetForNewSession();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) => _NoteSelectorSheet(notesAsync: notesAsync),
    ).whenComplete(() {
      ref.read(_noteSelectorShowingProvider.notifier).state = false;
    });
  }

  void _showContentPreview(
    BuildContext context,
    WidgetRef ref,
    dynamic item,
  ) {
    final content = item.plainBody as String? ?? '';
    final platform = item.platformStyle as String? ?? 'generic';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) =>
          _ContentPreviewSheet(content: content, platform: platform),
    );
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.month}/${dt.day}';
  }
}

/// Bottom sheet for selecting notes and providing a topic before starting
/// the AI composition flow.
class _NoteSelectorSheet extends ConsumerStatefulWidget {
  final AsyncValue<List<dynamic>> notesAsync;

  const _NoteSelectorSheet({required this.notesAsync});

  @override
  ConsumerState<_NoteSelectorSheet> createState() =>
      _NoteSelectorSheetState();
}

class _NoteSelectorSheetState extends ConsumerState<_NoteSelectorSheet> {
  final _topicController = TextEditingController();
  String _platformStyle = 'generic';
  final Set<String> _selectedIds = {};
  late final VoidCallback _routeListener;

  List<(String, String)> _platformOptions(AppLocalizations l10n) => [
        ('generic', l10n.platformGeneric),
        ('xhs', l10n.platformXhs),
        ('twitter', l10n.platformTwitter),
        ('blog', l10n.platformBlog),
        ('linkedin', l10n.platformLinkedin),
      ];

  @override
  void initState() {
    super.initState();
    _routeListener = () {
      if (!mounted) return;
      final location = GoRouterState.of(context).uri.path;
      if (!location.startsWith('/compose')) {
        Navigator.pop(context);
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GoRouter.of(context).routerDelegate.addListener(_routeListener);
    });
  }

  @override
  void dispose() {
    try {
      GoRouter.of(context).routerDelegate.removeListener(_routeListener);
    } catch (_) {}
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary)
                      .withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.newComposition,
                    style: AppTextStyles.headline,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Topic field
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: l10n.topicOrTheme,
                  hintText: l10n.topicHint,
                  prefixIcon: const Icon(Icons.lightbulb_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onChanged: (v) =>
                    ref.read(composeSessionProvider.notifier).setTopic(v),
              ),
            ),
            // Platform selector
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s8,
                AppSpacing.md,
                AppSpacing.s4,
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _platformStyle,
                decoration: InputDecoration(
                  labelText: l10n.targetPlatform,
                  prefixIcon: const Icon(Icons.share_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                items: _platformOptions(l10n)
                    .map((o) =>
                        DropdownMenuItem(value: o.$1, child: Text(o.$2)),)
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _platformStyle = v);
                    ref
                        .read(composeSessionProvider.notifier)
                        .setPlatformStyle(v);
                  }
                },
              ),
            ),
            // Note list label
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.s8,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.selectNotes,
                    style: AppTextStyles.title.copyWith(fontSize: 14),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      l10n.selectedCount(_selectedIds.length),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Note list
            Expanded(
              child: widget.notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.noNotesAvailableCreate,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final title = note.plainTitle ?? l10n.untitled;
                      final preview = note.plainContent != null &&
                              note.plainContent!.length > 60
                          ? '${note.plainContent!.substring(0, 60)}...'
                          : note.plainContent ?? '';
                      final isSelected = _selectedIds.contains(note.id);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedIds.add(note.id);
                            } else {
                              _selectedIds.remove(note.id);
                            }
                          });
                          ref
                              .read(composeSessionProvider.notifier)
                              .toggleNoteSelection(
                                note.id,
                                note.plainContent ?? '',
                              );
                        },
                      );
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 3,
                  shrinkWrap: true,
                  itemBuilder: (_, __) => const AppLoadingCard(),
                ),
                error: (err, _) {
                  final appError = ErrorMapper.map(err);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        ErrorDisplay.userMessage(appError, l10n),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Start button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty ||
                            _topicController.text.isEmpty
                        ? null
                        : () {
                            final sessionId = ref.read(
                              composeSessionProvider,
                            ).sessionId;
                            Navigator.pop(context);
                            final navContext =
                                rootNavigatorKey.currentContext;
                            if (navContext != null && navContext.mounted) {
                              navContext.push('/compose/cluster/$sessionId');
                            }
                          },
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(l10n.startComposing),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet that displays generated content with copy and save-as-note actions.
class _ContentPreviewSheet extends ConsumerStatefulWidget {
  final String content;
  final String platform;

  const _ContentPreviewSheet({required this.content, required this.platform});

  @override
  ConsumerState<_ContentPreviewSheet> createState() =>
      _ContentPreviewSheetState();
}

class _ContentPreviewSheetState
    extends ConsumerState<_ContentPreviewSheet> {
  bool _isSaving = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.info(context, message: l10n.copiedToClipboard);
    }
  }

  Future<void> _saveAsNote() async {
    if (widget.content.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final noteId = const Uuid().v4();

      String encryptedContent;
      String? encryptedTitle;

      if (crypto.isUnlocked) {
        encryptedContent =
            await crypto.encryptForItem(noteId, widget.content);
        final title = widget.content.length > 50
            ? widget.content.substring(0, 50)
            : widget.content;
        encryptedTitle = await crypto.encryptForItem(noteId, title);
      } else {
        encryptedContent = widget.content;
        encryptedTitle = widget.content.length > 50
            ? widget.content.substring(0, 50)
            : widget.content;
      }

      await db.notesDao.createNote(
        id: noteId,
        encryptedContent: encryptedContent,
        encryptedTitle: encryptedTitle,
        plainContent: widget.content,
        plainTitle: widget.content.length > 50
            ? widget.content.substring(0, 50)
            : widget.content,
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackBar.info(context, message: l10n.savedAsNote);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        final l10n = AppLocalizations.of(context)!;
        AppSnackBar.error(
          context,
          message: ErrorDisplay.userMessage(appError, l10n),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary)
                    .withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.s8,
              AppSpacing.md,
              AppSpacing.s4,
            ),
            child: Row(
              children: [
                Text(
                  l10n.contentPreview,
                  style: AppTextStyles.headline,
                ),
                const Spacer(),
                if (widget.platform != 'generic')
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        widget.platform,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Content
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkInputFill
                  : AppColors.lightInputFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                widget.content.isEmpty ? l10n.noContent : widget.content,
                style: AppTextStyles.body.copyWith(
                  height: 1.6,
                ),
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.copy),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveAsNote,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.saveAsNote),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
