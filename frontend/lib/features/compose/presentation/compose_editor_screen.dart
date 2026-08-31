import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../publish/presentation/widgets/publish_from_editor_sheet.dart';
import '../data/compose_providers.dart';
import 'widgets/refinement_chat.dart';

/// Full text editor with AI-generated content displayed via streaming.
///
/// Shows the draft text in an editable area with real-time streaming
/// display. Includes actions to adapt style, save as note (encrypted),
/// and navigate back to refine earlier stages.
class ComposeEditorScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const ComposeEditorScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ComposeEditorScreen> createState() =>
      _ComposeEditorScreenState();
}

class _ComposeEditorScreenState extends ConsumerState<ComposeEditorScreen> {
  late TextEditingController _editorController;
  final _scrollController = ScrollController();
  bool _isSaving = false;

  ComposeSessionNotifier? _cachedNotifier;

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(composeSessionProvider.notifier);
      _cachedNotifier = notifier;
      final session = ref.read(composeSessionProvider);
      _editorController.text = session.draft;
    });
  }

  @override
  void dispose() {
    _cachedNotifier?.cancel();
    _editorController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(composeSessionProvider);

    // Surface refinement failures with an existing draft via a SnackBar.
    // The full-screen error state below only covers the empty-draft case, so
    // without this listener a failed refinement would fail silently.
    ref.listen<ComposeSessionState>(composeSessionProvider, (previous, next) {
      final error = next.error;
      if (error == null || error.isEmpty) return;
      if (previous?.error == error) return;
      if (next.draft.isEmpty) return; // Full-screen error state handles this.
      AppSnackBar.error(context, message: error);
    });

    if (session.isLoading && _editorController.text != session.draft) {
      _editorController.text = session.draft;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(l10n.editorTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.publish,
            onPressed: session.isLoading
                ? null
                : () => _publishDraft(context),
          ),
          IconButton(
            icon: const Icon(Icons.style),
            tooltip: l10n.adaptStyleFor(session.platformStyle),
            onPressed: session.isLoading || session.draft.isEmpty
                ? null
                : () => _adaptStyle(ref, l10n),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: l10n.saveNoteTooltip,
            onPressed: session.isLoading || session.draft.isEmpty || _isSaving
                ? null
                : () => _saveAsNote(context, ref),
          ),
        ],
      ),
      body: _buildBody(context, session),
    );
  }

  Widget _buildBody(BuildContext context, ComposeSessionState session) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Error state
    if (session.error != null && session.draft.isEmpty) {
      return _buildErrorState(session, l10n, isDark);
    }

    return Column(
      children: [
        // Streaming indicator
        if (session.isLoading) _buildStreamingBanner(session, l10n, isDark),

        // Title area
        if (session.outline != null) _buildTitleArea(session, isDark),

        // Editor area (top — editable draft)
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.s4,
              AppSpacing.md,
              AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.smOf(Theme.of(context).brightness),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: TextField(
                controller: _editorController,
                scrollController: _scrollController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppTextStyles.body.copyWith(height: 1.7),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.compositionHint,
                  hintStyle: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.s16),
                ),
                onChanged: (text) {
                  ref.read(composeSessionProvider.notifier).updateDraft(text);
                },
                scrollPadding: const EdgeInsets.only(bottom: 120),
              ),
            ),
          ),
        ),

        // AI refinement chat (split view — bottom)
        Expanded(
          flex: 2,
          child: RefinementChat(sessionId: widget.sessionId),
        ),

        // Bottom action bar
        _buildBottomBar(session, l10n, isDark),
      ],
    );
  }

  Widget _buildErrorState(
    ComposeSessionState session,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              session.error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: () {
                ref.read(composeSessionProvider.notifier).clearError();
                ref
                    .read(composeSessionProvider.notifier)
                    .expandToDraft(quotaExceededMessage: l10n.aiQuotaExceeded);
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBanner(
    ComposeSessionState session,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentMintBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentMintText,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            l10n.aiWriting,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.accentMintText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            l10n.charsCount(session.draft.length),
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleArea(ComposeSessionState session, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s12,
        AppSpacing.md,
        AppSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(150),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  session.outline!.title,
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              height: 0.5,
              color: isDark
                  ? AppColors.darkDivider.withAlpha(60)
                  : AppColors.lightDivider.withAlpha(80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    ComposeSessionState session,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.s4,
          AppSpacing.md,
          AppSpacing.s8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.smOf(Theme.of(context).brightness),
        ),
        child: Row(
          children: [
            // Back to outline
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkInputFill
                      : AppColors.lightInputFill,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 16,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      l10n.outlineButton,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Platform chip
            if (session.platformStyle != 'generic') ...[
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  session.platformStyle,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Word count
            Text(
              l10n.wordsCount(_countWords(session.draft)),
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),

            // Save button
            FilledButton.icon(
              onPressed: session.draft.isEmpty || _isSaving || session.isLoading
                  ? null
                  : () => _saveAsNote(context, ref),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(l10n.saveAsNote),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countWords(String text) {
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Hands the current draft off to the publish flow.
  ///
  /// The title is the first non-empty line with markdown heading markers
  /// stripped; the content is the full draft.
  void _publishDraft(BuildContext context) {
    final session = ref.read(composeSessionProvider);
    final l10n = AppLocalizations.of(context)!;

    if (session.draft.trim().isEmpty) {
      AppSnackBar.error(context, message: l10n.titleAndContentRequired);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PublishFromEditorSheet(
        title: _extractPublishTitle(session.draft),
        content: session.draft,
        initialTags: const [],
        // Carry the compose template through so the publish sheet's AI
        // polish keeps the template's structure and tone.
        template: session.selectedTemplate,
      ),
    );
  }

  /// Extracts the publish title from the draft: the first non-empty line with
  /// leading markdown heading markers (`#`) stripped.
  String _extractPublishTitle(String draft) {
    for (final line in draft.split('\n')) {
      final stripped = line.trim().replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (stripped.isNotEmpty) return stripped;
    }
    return '';
  }

  Future<void> _adaptStyle(WidgetRef ref, AppLocalizations l10n) async {
    await ref
        .read(composeSessionProvider.notifier)
        .adaptStyle(quotaExceededMessage: l10n.aiQuotaExceeded);
  }

  Future<void> _saveAsNote(BuildContext context, WidgetRef ref) async {
    setState(() => _isSaving = true);

    try {
      final noteId =
          await ref.read(composeSessionProvider.notifier).saveDraftAsNote();

      if (!mounted) return;
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      if (noteId != null) {
        AppSnackBar.info(
          context,
          message: l10n.savedAsNote,
          actionLabel: l10n.viewAction,
          onAction: () => context.push('/notes/$noteId'),
        );
      } else {
        AppSnackBar.error(context, message: l10n.failedToSaveNote);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
