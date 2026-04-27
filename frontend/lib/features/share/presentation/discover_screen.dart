import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/widgets/app_components.dart';
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
///
/// No authentication is required to view the feed, but reactions
/// require the user to be logged in.
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
        // Don't advance offset on failure so retry can work.
        _currentOffset -= 20;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.failedToLoadMore(e.toString()) ??
                'Failed to load more: $e',
          ),
        ),
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
      // The FutureProvider will surface the error.
      debugPrint('[DiscoverScreen] failed to refresh feed: $e');
    }
  }

  Future<void> _toggleReaction(String shareId, String reactionType) async {
    final api = ref.read(apiClientProvider);
    final stateKey = '$shareId:$reactionType';
    final reactionState = ref.read(reactionStateProvider(shareId));
    final wasActive = reactionState[stateKey] ?? false;

    // Optimistic update.
    ref.read(reactionStateProvider(shareId).notifier).update(
          (state) => {...state, stateKey: !wasActive},
        );

    // Update local counts optimistically.
    final itemIndex = _allItems.indexWhere((item) => item['id'] == shareId);
    if (itemIndex >= 0) {
      final item = Map<String, dynamic>.from(_allItems[itemIndex]);
      final countKey =
          reactionType == 'heart' ? 'reaction_heart' : 'reaction_bookmark';
      item[countKey] = (item[countKey] as int? ?? 0) + (wasActive ? -1 : 1);
      setState(() {
        _allItems[itemIndex] = item;
      });
    }

    try {
      final result = await api.toggleReaction(shareId, reactionType);
      if (!mounted) return;

      // Update with server truth.
      final active = result['active'] as bool;
      ref.read(reactionStateProvider(shareId).notifier).update(
            (state) => {...state, stateKey: active},
          );

      final count = result['count'] as int;
      if (itemIndex >= 0) {
        final item = Map<String, dynamic>.from(_allItems[itemIndex]);
        final countKey =
            reactionType == 'heart' ? 'reaction_heart' : 'reaction_bookmark';
        item[countKey] = count;
        setState(() {
          _allItems[itemIndex] = item;
        });
      }
    } catch (e) {
      if (!mounted) return;
      // Revert optimistic update.
      ref.read(reactionStateProvider(shareId).notifier).update(
            (state) => {...state, stateKey: wasActive},
          );
      if (itemIndex >= 0) {
        final item = Map<String, dynamic>.from(_allItems[itemIndex]);
        final countKey =
            reactionType == 'heart' ? 'reaction_heart' : 'reaction_bookmark';
        item[countKey] = (item[countKey] as int? ?? 0) + (wasActive ? 1 : -1);
        setState(() {
          _allItems[itemIndex] = item;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.reactionFailed ?? 'Failed to react',
          ),
          duration: AppDurations.snackbarDuration,
        ),
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
      ),
      body: feedAsync.when(
        data: (initialItems) {
          // Seed items on first load.
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _allItems.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _allItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return _DiscoverCard(
            item: _allItems[index],
            onReact: _toggleReaction,
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppLoadingCard(),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            l10n.failedToLoadDiscoverFeed,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
    );
  }
}

// ── Discover Card ──────────────────────────────────

class _DiscoverCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final void Function(String shareId, String reactionType) onReact;

  const _DiscoverCard({
    required this.item,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final shareId = item['id'] as String;
    final encryptedTitle = item['encrypted_title'] as String? ?? '';
    final viewCount = item['view_count'] as int? ?? 0;
    final heartCount = item['reaction_heart'] as int? ?? 0;
    final bookmarkCount = item['reaction_bookmark'] as int? ?? 0;
    final hasPassword = item['has_password'] as bool? ?? false;

    final reactionState = ref.watch(reactionStateProvider(shareId));
    final isHearted = reactionState['$shareId:heart'] ?? false;
    final isBookmarked = reactionState['$shareId:bookmark'] ?? false;

    final createdAt = item['created_at'] as String? ?? '';
    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeAgo = l10n.justNow;
        } else if (diff.inHours < 1) {
          timeAgo = l10n.minutesAgo(diff.inMinutes);
        } else if (diff.inDays < 1) {
          timeAgo = l10n.hoursAgo(diff.inHours);
        } else if (diff.inDays < 30) {
          timeAgo = l10n.daysAgo(diff.inDays);
        } else {
          timeAgo = l10n.monthsAgo((diff.inDays / 30).round());
        }
      } catch (e) {
        debugPrint('[DiscoverScreen] failed to format time-ago: $e');
        timeAgo = '';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/share/$shareId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      encryptedTitle.isNotEmpty
                          ? encryptedTitle
                          : l10n.encryptedNote,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasPassword) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$viewCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (timeAgo.isNotEmpty) ...[
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Reactions row
              Row(
                children: [
                  _ReactionButton(
                    icon: isHearted ? Icons.favorite : Icons.favorite_border,
                    count: heartCount,
                    isActive: isHearted,
                    activeColor: Colors.red,
                    onTap: () => onReact(shareId, 'heart'),
                  ),
                  const SizedBox(width: 12),
                  _ReactionButton(
                    icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    count: bookmarkCount,
                    isActive: isBookmarked,
                    activeColor: theme.colorScheme.primary,
                    onTap: () => onReact(shareId, 'bookmark'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reaction Button ────────────────────────────────

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? activeColor : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
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
