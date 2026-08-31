import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_components.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../data/discover_providers.dart';

// ── Screen ─────────────────────────────────────────

/// Public note discovery feed.
///
/// Displays opt-in public shared notes in a card-based feed.
/// Supports pull-to-refresh, infinite scroll pagination, and
/// heart/bookmark reaction toggles.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollController = ScrollController();
  int _currentOffset = 0;
  List<Map<String, dynamic>> _allItems = [];
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    _currentOffset += 20;
    try {
      final api = ref.read(apiClientProvider);
      final newItems = await api.discoverFeed(
        limit: 20,
        offset: _currentOffset,
      );
      if (!mounted) return;
      setState(() {
        _allItems = [..._allItems, ...newItems];
        _hasMore = newItems.length >= 20;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _currentOffset -= 20;
      });
      AppSnackBar.error(
        context,
        message:
            AppLocalizations.of(context)?.failedToLoadMore(
                  ErrorDisplay.userMessage(
                    ErrorMapper.map(e),
                    AppLocalizations.of(context)!,
                  ),
                ) ??
                'Failed to load more: $e',
      );
    }
  }

  Future<void> _refresh() async {
    _currentOffset = 0;
    _hasMore = true;
    ref.invalidate(discoverFeedProvider(0));
    final api = ref.read(apiClientProvider);
    try {
      final items = await api.discoverFeed(limit: 20, offset: 0);
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _hasMore = items.length >= 20;
      });
    } catch (e) {
      debugPrint('[DiscoverScreen] failed to refresh feed: $e');
    }
  }

  Future<void> _toggleReaction(String shareId, String reactionType) async {
    final api = ref.read(apiClientProvider);
    final stateKey = '$shareId:$reactionType';
    final reactionState = ref.read(reactionStateProvider(shareId));
    final wasActive = reactionState[stateKey] ?? false;

    ref
        .read(reactionStateProvider(shareId).notifier)
        .update((state) => {...state, stateKey: !wasActive});

    final itemIndex = _allItems.indexWhere((item) => item['id'] == shareId);
    if (itemIndex >= 0) {
      final item = Map<String, dynamic>.from(_allItems[itemIndex]);
      final countKey = reactionType == 'heart'
          ? 'reaction_heart'
          : 'reaction_bookmark';
      item[countKey] = (item[countKey] as int? ?? 0) + (wasActive ? -1 : 1);
      setState(() {
        _allItems[itemIndex] = item;
      });
    }

    try {
      final result = await api.toggleReaction(shareId, reactionType);
      if (!mounted) return;

      final active = result['active'] as bool;
      ref
          .read(reactionStateProvider(shareId).notifier)
          .update((state) => {...state, stateKey: active});

      final count = result['count'] as int;
      if (itemIndex >= 0) {
        final item = Map<String, dynamic>.from(_allItems[itemIndex]);
        final countKey = reactionType == 'heart'
            ? 'reaction_heart'
            : 'reaction_bookmark';
        item[countKey] = count;
        setState(() {
          _allItems[itemIndex] = item;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ref
          .read(reactionStateProvider(shareId).notifier)
          .update((state) => {...state, stateKey: wasActive});
      if (itemIndex >= 0) {
        final item = Map<String, dynamic>.from(_allItems[itemIndex]);
        final countKey = reactionType == 'heart'
            ? 'reaction_heart'
            : 'reaction_bookmark';
        item[countKey] = (item[countKey] as int? ?? 0) + (wasActive ? 1 : -1);
        setState(() {
          _allItems[itemIndex] = item;
        });
      }

      AppSnackBar.error(
        context,
        message:
            AppLocalizations.of(context)?.reactionFailed ?? 'Failed to react',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedAsync = ref.watch(discoverFeedProvider(0));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.discoverFeed),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: feedAsync.when(
        data: (initialItems) {
          if (_allItems.isEmpty) {
            _allItems = initialItems;
            _hasMore = initialItems.length >= 20;
          }
          return _buildFeed(context);
        },
        loading: () => _buildLoadingSkeleton(),
        error: (error, _) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildFeed(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_allItems.isEmpty) {
      return EmptyState(
        icon: Icons.explore_outlined,
        title: l10n.noPublicNotes,
        subtitle: l10n.noPublicNotesDesc,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.s4,
          AppSpacing.md,
          96,
        ),
        itemCount: _allItems.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _allItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: _DiscoverCard(
              item: _allItems[index],
              index: index,
              onReact: _toggleReaction,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        96,
      ),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.s8),
        child: AppLoadingCard(),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              l10n.failedToLoadDiscoverFeed,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              '$error',
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: () {
                _currentOffset = 0;
                _allItems = [];
                _hasMore = true;
                ref.invalidate(discoverFeedProvider(0));
              },
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Discover Card ──────────────────────────────────

class _DiscoverCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final int index;
  final void Function(String shareId, String reactionType) onReact;

  const _DiscoverCard({
    required this.item,
    required this.index,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shareId = item['id'] as String;
    final encryptedTitle = item['encrypted_title'] as String? ?? '';
    final viewCount = item['view_count'] as int? ?? 0;
    final heartCount = item['reaction_heart'] as int? ?? 0;
    final bookmarkCount = item['reaction_bookmark'] as int? ?? 0;
    final hasPassword = item['has_password'] as bool? ?? false;
    final authorName = item['author_name'] as String? ?? '';

    final reactionState = ref.watch(reactionStateProvider(shareId));
    final isHearted = reactionState['$shareId:heart'] ?? false;
    final isBookmarked = reactionState['$shareId:bookmark'] ?? false;

    // Warm pastel cycling
    const pastelBgs = [
      AppColors.accentPeachBg,
      AppColors.accentYellowBg,
      AppColors.accentMintBg,
      AppColors.accentPeachBg,
    ];
    const pastelTexts = [
      AppColors.accentPeachText,
      AppColors.accentYellowText,
      AppColors.accentMintText,
      AppColors.accentPeachText,
    ];
    final accentBg = pastelBgs[index % pastelBgs.length];
    final accentText = pastelTexts[index % pastelTexts.length];

    final createdAt = item['created_at'] as String? ?? '';
    final timeAgo = _formatTimeAgo(createdAt, l10n);

    return GestureDetector(
      onTap: () => context.push('/share/$shareId'),
      child: Container(
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
            // Header row: avatar + author handle + time
            Row(
              children: [
                // Author avatar
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentText,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    authorName.isNotEmpty ? authorName : '---',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ),
                if (timeAgo.isNotEmpty)
                  Text(
                    timeAgo,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                if (hasPassword) ...[
                  const SizedBox(width: AppSpacing.s4),
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s8),

            // Title
            Text(
              encryptedTitle.isNotEmpty ? encryptedTitle : l10n.encryptedNote,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.s12),

            // Footer row: reactions + views
            Row(
              children: [
                // Heart
                _ReactionButton(
                  icon: isHearted ? Icons.favorite : Icons.favorite_border,
                  count: heartCount,
                  isActive: isHearted,
                  activeColor: AppColors.error,
                  isDark: isDark,
                  onTap: () => onReact(shareId, 'heart'),
                ),
                const SizedBox(width: AppSpacing.s12),
                // Bookmark
                _ReactionButton(
                  icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  count: bookmarkCount,
                  isActive: isBookmarked,
                  activeColor: AppColors.primary,
                  isDark: isDark,
                  onTap: () => onReact(shareId, 'bookmark'),
                ),
                const Spacer(),
                // Views
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                const SizedBox(width: AppSpacing.s4),
                Text(
                  '$viewCount',
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
    );
  }

  String _formatTimeAgo(String createdAt, AppLocalizations l10n) {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return l10n.justNow;
      if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
      if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
      if (diff.inDays < 30) return l10n.daysAgo(diff.inDays);
      return l10n.monthsAgo((diff.inDays / 30).round());
    } catch (e) {
      return '';
    }
  }
}

// ── Reaction Button ────────────────────────────────

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? activeColor
        : (isDark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: 4,
        ),
        decoration: isActive
            ? BoxDecoration(
                color: activeColor.withAlpha(15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.s4),
            Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
