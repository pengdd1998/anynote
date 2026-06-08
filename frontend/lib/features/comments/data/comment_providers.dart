import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart';

// ── Comment List ────────────────────────────────────────

/// Fetches comments for a shared note (paginated).
/// The shareId is the ID of the shared note.
final commentsProvider =
    FutureProvider.family<Map<String, dynamic>, CommentsQuery>(
  (ref, query) async {
    final api = ref.read(apiClientProvider);
    return api.listComments(
      query.shareId,
      limit: query.limit,
      offset: query.offset,
    );
  },
);

/// Query parameters for fetching comments.
class CommentsQuery {
  final String shareId;
  final int limit;
  final int offset;

  const CommentsQuery({
    required this.shareId,
    this.limit = 50,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentsQuery &&
          shareId == other.shareId &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(shareId, limit, offset);
}

// ── Comment Action State ────────────────────────────────

/// State for tracking comment creation/deletion operations.
class CommentActionState {
  final bool isLoading;
  final String? error;

  const CommentActionState({this.isLoading = false, this.error});

  CommentActionState copyWith({bool? isLoading, String? error}) {
    return CommentActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Manages comment creation and deletion state.
class CommentActionNotifier extends StateNotifier<CommentActionState> {
  final Ref _ref;

  CommentActionNotifier(this._ref) : super(const CommentActionState());

  /// Create a comment on a shared note.
  Future<String?> createComment(
    String shareId, {
    required String content,
    String? parentId,
  }) async {
    state = const CommentActionState(isLoading: true);
    try {
      final api = _ref.read(apiClientProvider);
      final result = await api.createComment(
        shareId,
        encryptedContent: content,
        parentId: parentId,
      );
      state = const CommentActionState();
      // Invalidate the comments list for this share to trigger a refresh.
      _ref.invalidate(commentsProvider);
      return result['id'] as String?;
    } catch (e) {
      debugPrint('[CommentAction] create failed: $e');
      state = CommentActionState(error: e.toString());
      return null;
    }
  }

  /// Delete a comment by ID.
  Future<bool> deleteComment(
    String commentId, {
    required String shareId,
  }) async {
    state = const CommentActionState(isLoading: true);
    try {
      final api = _ref.read(apiClientProvider);
      await api.deleteComment(commentId);
      state = const CommentActionState();
      _ref.invalidate(commentsProvider);
      return true;
    } catch (e) {
      debugPrint('[CommentAction] delete failed: $e');
      state = CommentActionState(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = const CommentActionState();
  }
}

final commentActionProvider =
    StateNotifierProvider<CommentActionNotifier, CommentActionState>(
  (ref) => CommentActionNotifier(ref),
);
