import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../data/comment_providers.dart';

/// Displays a paginated list of comments for a shared note.
class CommentList extends ConsumerStatefulWidget {
  final String shareId;
  final String? currentUserId;

  const CommentList({super.key, required this.shareId, this.currentUserId});

  @override
  ConsumerState<CommentList> createState() => _CommentListState();
}

class _CommentListState extends ConsumerState<CommentList> {
  final _scrollController = ScrollController();
  int _offset = 0;
  static const _pageSize = 20;
  List<Map<String, dynamic>> _comments = [];
  int _total = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  ProviderSubscription<AsyncValue<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up a one-time listener for provider invalidation so the comment
    // list refreshes automatically after a new comment is created.
    _subscription?.close();
    _subscription = ref.listenManual(
      commentsProvider(CommentsQuery(shareId: widget.shareId)),
      (_, next) {
        if (next.hasValue && mounted) _refresh();
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final result = await ref.read(
        commentsProvider(
          CommentsQuery(
            shareId: widget.shareId,
            limit: _pageSize,
            offset: _offset,
          ),
        ).future,
      );
      if (!mounted) return;
      final list =
          (result['comments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final total = result['total'] as int? ?? 0;
      setState(() {
        _comments = list;
        _total = total;
        _hasMore = _comments.length < total;
      });
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _offset += _pageSize;
    try {
      final result = await ref.read(
        commentsProvider(
          CommentsQuery(
            shareId: widget.shareId,
            limit: _pageSize,
            offset: _offset,
          ),
        ).future,
      );
      if (!mounted) return;
      final list =
          (result['comments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _comments.addAll(list);
        _hasMore = _comments.length < _total;
        _isLoadingMore = false;
      });
    } catch (_) {
      _offset -= _pageSize;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    _offset = 0;
    _hasMore = true;
    await _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n?.noCommentsYet ?? 'No comments yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Text(
            l10n?.commentCount(_total) ?? '$_total comments',
            style: theme.textTheme.titleSmall,
          ),
        ),
        ..._comments.map((comment) => _CommentTile(
              comment: comment,
              currentUserId: widget.currentUserId,
              onDelete: () => _deleteComment(comment['id'] as String),
            )),
        if (_hasMore)
          TextButton(
            onPressed: _isLoadingMore ? null : _loadMore,
            child: Text(
              _isLoadingMore
                  ? (l10n?.loading ?? 'Loading...')
                  : (l10n?.loadMore ?? 'Load more'),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final action = ref.read(commentActionProvider.notifier);
    await action.deleteComment(commentId, shareId: widget.shareId);
    _refresh();
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String? currentUserId;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    this.currentUserId,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final userId = comment['user_id'] as String?;
    final createdAt = comment['created_at'] as String?;
    final content = comment['encrypted_content'] as String? ?? '';
    final isOwner = userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.mdBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    (userId ?? '?').substring(0, 1).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    _formatDate(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: onDelete,
                    tooltip: l10n?.delete ?? 'Delete',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
