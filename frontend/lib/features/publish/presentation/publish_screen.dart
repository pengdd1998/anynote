import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/keyboard_scroll_mixin.dart';
import '../../../core/widgets/sync_status_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../data/publish_providers.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen>
    with WidgetsBindingObserver, KeyboardScrollMixin {
  static const _platformIcons = <String, IconData>{
    'xiaohongshu': Icons.camera_alt,
    'wechat': Icons.chat,
    'zhihu': Icons.question_answer,
    'medium': Icons.article,
  };

  static const _platformAccents = <String, _PlatformAccent>{
    'xiaohongshu': _PlatformAccent(
      bg: AppColors.accentPeachBg,
      text: AppColors.accentPeachText,
    ),
    'wechat': _PlatformAccent(
      bg: AppColors.accentMintBg,
      text: AppColors.accentMintText,
    ),
    'zhihu': _PlatformAccent(
      bg: AppColors.accentPeachBg,
      text: AppColors.accentPeachText,
    ),
    'medium': _PlatformAccent(
      bg: AppColors.accentYellowBg,
      text: AppColors.accentYellowText,
    ),
  };

  String? _selectedPlatform;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    onKeyboardMetricsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platformsAsync = ref.watch(connectedPlatformsProvider);
    final historyAsync = ref.watch(publishHistoryProvider);
    final publishState = ref.watch(publishActionProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(l10n.publish),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [SyncStatusWidget()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(connectedPlatformsProvider);
              ref.invalidate(publishHistoryProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.s4,
                AppSpacing.md,
                200,
              ),
          children: [
            // Platform cards
            _buildSectionLabel(l10n.connectedPlatforms),
            const SizedBox(height: AppSpacing.s8),
            platformsAsync.when(
              data: (platforms) {
                if (platforms.isEmpty) return _buildNoPlatforms(l10n);
                // Row of 48px rounded share-target squares.
                return Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s12,
                  children: platforms
                      .map(
                        (p) => _buildPlatformSquare(p, l10n),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (error, _) => _buildPlatformError(error, l10n),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Publish form
            _buildSectionLabel(l10n.publishContent),
            const SizedBox(height: AppSpacing.s8),
            _buildPublishForm(publishState),

            const SizedBox(height: AppSpacing.lg),

            // Recent publications
            _buildSectionLabel(l10n.recentPublications),
            const SizedBox(height: AppSpacing.s8),
            historyAsync.when(
              data: (history) {
                if (history.isEmpty) return _buildNoPublications(l10n);
                final recent = history.take(3).toList();
                return Column(
                  children: [
                    ...recent.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                      child: _buildHistoryCard(item, l10n),
                    ),),
                    if (history.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s4),
                        child: OutlinedButton(
                          onPressed: () => context.push('/publish/history'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: Text(l10n.viewAll(history.length)),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (error, _) => _buildHistoryError(error, l10n),
            ),
          ],
        ),                // ListView
      );                  // RefreshIndicator
    },                    // builder callback
  ),                      // LayoutBuilder
);                        // Scaffold + return
  }

  Widget _buildSectionLabel(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary,
      ),
    );
  }

  /// A 48px rounded share-target square with the platform name below.
  /// Selected state fills the square with the brand purple.
  Widget _buildPlatformSquare(Map<String, dynamic> p, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name =
        p['name']?.toString() ?? p['platform']?.toString() ?? l10n.unknown;
    final platformKey = p['key']?.toString() ?? name.toLowerCase();
    final icon = _platformIcons[platformKey] ?? Icons.language;
    final isSelected = _selectedPlatform == platformKey;
    final accent = _platformAccents[platformKey] ??
        const _PlatformAccent(
          bg: AppColors.accentPeachBg,
          text: AppColors.accentPeachText,
        );

    return GestureDetector(
      onTap: () => setState(() => _selectedPlatform = platformKey),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCardBg : AppColors.lightCardBg),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : accent.text,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primaryText
                    : (isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlatforms(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentPeachBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.add_link_outlined,
              size: 28,
              color: AppColors.accentPeachText,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            l10n.noPlatformsConnected,
            style: AppTextStyles.body.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          FilledButton.tonal(
            onPressed: () => context.push('/settings/platforms'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Text(l10n.connectAPlatform),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformError(Object error, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appError = ErrorMapper.map(error);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
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
          Text(l10n.failedToLoadPlatforms),
          const SizedBox(height: AppSpacing.s4),
          Text(
            ErrorDisplay.userMessage(appError, l10n),
            style: AppTextStyles.caption.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          FilledButton.tonal(
            onPressed: () => ref.invalidate(connectedPlatformsProvider),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishForm(PublishActionState state) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPublish = _selectedPlatform != null && !state.isLoading;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
            ),
            decoration: InputDecoration(
              labelText: l10n.title,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _contentController,
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
            ),
            decoration: InputDecoration(
              labelText: l10n.content,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _tagsController,
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 40,
            ),
            decoration: InputDecoration(
              labelText: l10n.tagsCommaSeparated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              isDense: true,
              hintText: l10n.tagsHint,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          if (_selectedPlatform == null)
            Text(
              l10n.selectPlatformToPublish,
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: Text(
                state.error!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          if (state.result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    l10n.publishedStatus(
                      state.result?['status'] ?? 'pending',
                    ),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.s4),
          if (canPublish && _contentController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: OutlinedButton.icon(
                onPressed: _showPreview,
                icon: const Icon(Icons.preview_outlined, size: 18),
                label: Text(l10n.preview),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canPublish ? _handlePublish : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
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
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = item['title']?.toString() ?? l10n.untitled;
    final platform = item['platform']?.toString() ?? l10n.unknown;
    final status = item['status']?.toString() ?? 'unknown';
    final createdAt = item['created_at']?.toString() ?? '';
    final platformURL = item['platform_url']?.toString() ?? '';

    final statusIcon = switch (status) {
      'published' => Icons.check_circle,
      'failed' => Icons.error,
      'publishing' => Icons.sync,
      'pending' => Icons.schedule,
      _ => Icons.help_outline,
    };

    // Pill chip colors per status (published = mint, pending = yellow).
    final chipBg = isDark
        ? (switch (status) {
            'published' => AppColors.darkSuccessBg,
            'failed' => AppColors.darkErrorBg,
            _ => AppColors.darkWarningBg,
          })
        : (switch (status) {
            'published' => AppColors.accentMintBg,
            'failed' => AppColors.lightErrorBg,
            'publishing' => AppColors.accentYellowBg,
            'pending' => AppColors.accentYellowBg,
            _ => AppColors.accentYellowBg,
          });
    final chipText = isDark
        ? (switch (status) {
            'published' => AppColors.success,
            'failed' => AppColors.error,
            _ => AppColors.warning,
          })
        : (switch (status) {
            'published' => AppColors.accentMintText,
            'failed' => AppColors.error,
            'publishing' => AppColors.accentYellowText,
            'pending' => AppColors.accentYellowText,
            _ => AppColors.accentYellowText,
          });

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          // Status icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(statusIcon, size: 18, color: chipText),
          ),
          const SizedBox(width: AppSpacing.s12),
          // Title + metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  '$platform${createdAt.isNotEmpty ? ' - $createdAt' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Action
          if (platformURL.isNotEmpty)
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(platformURL);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkInputFill
                      : AppColors.lightInputFill,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                status,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: chipText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoPublications(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : AppColors.lightCardBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentYellowBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.publish_outlined,
              size: 28,
              color: AppColors.accentYellowText,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            l10n.noPublicationsYet,
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

  Widget _buildHistoryError(Object error, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appError = ErrorMapper.map(error);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
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
          Text(ErrorDisplay.userMessage(appError, l10n)),
          const SizedBox(height: AppSpacing.s8),
          FilledButton.tonal(
            onPressed: () => ref.invalidate(publishHistoryProvider),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePublish() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final tagsText = _tagsController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(context, message: l10n.titleAndContentRequired);
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
        AppSnackBar.info(context, message: l10n.publishRequestSubmitted);
        _titleController.clear();
        _contentController.clear();
        _tagsController.clear();
        ref.invalidate(publishHistoryProvider);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) ref.read(publishActionProvider.notifier).reset();
        });
      } else if (state.error != null && mounted) {
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

  /// Show a preview of the content as it will appear when published.
  void _showPreview() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final tags = _tagsController.text.trim();
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.preview,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              if (title.isNotEmpty)
                Text(
                  title,
                  style: AppTextStyles.display.copyWith(fontSize: 22),
                ),
              const SizedBox(height: AppSpacing.s8),
              if (_selectedPlatform != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardBg
                        : AppColors.lightCardBg,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    _selectedPlatform!.toUpperCase(),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                content,
                style: AppTextStyles.body.copyWith(height: 1.6),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                Wrap(
                  spacing: 6,
                  children: tags
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .map((t) => Chip(
                            label: Text('#$t', style: AppTextStyles.caption),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),)
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformAccent {
  final Color bg;
  final Color text;
  const _PlatformAccent({required this.bg, required this.text});
}
