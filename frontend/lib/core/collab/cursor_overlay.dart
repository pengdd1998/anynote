import 'package:flutter/material.dart';

import 'cursor_position_calculator.dart';

/// Data model for a remote collaborator's cursor position.
class CursorData {
  final String userId;
  final String username;
  final int position;

  /// Optional selection end. When null or equal to [position], this represents
  /// a collapsed cursor. When different, it represents a text selection range.
  final int? selectionEnd;
  final Color color;

  const CursorData({
    required this.userId,
    required this.username,
    required this.position,
    this.selectionEnd,
    required this.color,
  });

  /// Whether this cursor has an active selection range.
  bool get hasSelection => selectionEnd != null && selectionEnd != position;

  factory CursorData.fromMap(Map<String, dynamic> map) {
    return CursorData(
      userId: map['user_id'] as String? ?? '',
      username: map['username'] as String? ?? '???',
      position: map['position'] as int? ?? 0,
      selectionEnd: map['selection_end'] as int?,
      color: _colorForUser(map['user_id'] as String? ?? ''),
    );
  }

  /// Assign a deterministic color to each user.
  static Color _colorForUser(String userId) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
    ];
    final hash = userId.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CursorData &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          username == other.username &&
          position == other.position &&
          selectionEnd == other.selectionEnd &&
          color == other.color;

  @override
  int get hashCode =>
      Object.hash(userId, username, position, selectionEnd, color);
}

/// Overlay widget that renders remote collaborator cursors and selection ranges.
///
/// Accepts an optional [editorBox] reference to the editor's [RenderBox] for
/// precise cursor positioning. Falls back to a line-counting heuristic when
/// no render box is available.
///
/// Optional parameters for tuning the heuristic:
/// - [editorWidth]: visible editor width (used by fallback heuristic).
/// - [lineHeight]: estimated line height in pixels.
/// - [fontSize]: editor font size for chars-per-line estimation.
/// - [horizontalPadding]: left+right padding inside the editor.
class CursorOverlay extends StatelessWidget {
  final List<CursorData> cursors;

  /// The plain text content currently in the editor, used for heuristic
  /// positioning when no [RenderBox] is available.
  final String content;

  /// Optional reference to the editor's [RenderBox] for precise positioning.
  final RenderBox? editorBox;

  /// Fallback editor width when [editorBox] is null.
  final double editorWidth;

  /// Estimated line height.
  final double lineHeight;

  /// Editor font size for heuristic chars-per-line calculation.
  final double fontSize;

  /// Horizontal padding inside the editor.
  final double horizontalPadding;

  /// Duration for cursor position animation.
  final Duration animationDuration;

  const CursorOverlay({
    super.key,
    required this.cursors,
    this.content = '',
    this.editorBox,
    this.editorWidth = 300.0,
    this.lineHeight = 20.0,
    this.fontSize = 14.0,
    this.horizontalPadding = 16.0,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    if (cursors.isEmpty) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Render selection ranges first (behind cursors).
        for (final cursor in cursors)
          if (cursor.hasSelection) _buildSelectionHighlight(cursor),
        // Render cursors and labels on top.
        for (final cursor in cursors) _buildCursor(cursor),
      ],
    );
  }

  /// Build a semi-transparent highlight for a selection range.
  Widget _buildSelectionHighlight(CursorData cursor) {
    final range = CursorPositionCalculator.calculateSelectionRange(
      startOffset: cursor.position < (cursor.selectionEnd ?? cursor.position)
          ? cursor.position
          : (cursor.selectionEnd ?? cursor.position),
      endOffset: cursor.position < (cursor.selectionEnd ?? cursor.position)
          ? (cursor.selectionEnd ?? cursor.position)
          : cursor.position,
      content: content,
      editorBox: editorBox,
      editorWidth: editorWidth,
      lineHeight: lineHeight,
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
    );

    if (range == null) return const SizedBox.shrink();

    return Positioned(
      left: range.start.dx,
      top: range.start.dy,
      child: Container(
        width:
            (range.end.dx - range.start.dx).abs().clamp(2.0, double.infinity),
        height: (range.end.dy - range.start.dy + lineHeight)
            .clamp(lineHeight, double.infinity),
        decoration: BoxDecoration(
          color: cursor.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
    );
  }

  /// Build a single cursor line with animated position and a user avatar label.
  Widget _buildCursor(CursorData cursor) {
    final offset = CursorPositionCalculator.calculatePosition(
      characterOffset: cursor.position,
      content: content,
      editorBox: editorBox,
      editorWidth: editorWidth,
      lineHeight: lineHeight,
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
    );

    if (offset == null) return const SizedBox.shrink();

    return _AnimatedCursor(
      key: ValueKey('cursor_${cursor.userId}'),
      offset: offset,
      lineHeight: lineHeight,
      color: cursor.color,
      username: cursor.username,
      animationDuration: animationDuration,
    );
  }
}

/// An animated cursor that smoothly transitions between positions.
class _AnimatedCursor extends StatelessWidget {
  final Offset offset;
  final double lineHeight;
  final Color color;
  final String username;
  final Duration animationDuration;

  const _AnimatedCursor({
    super.key,
    required this.offset,
    required this.lineHeight,
    required this.color,
    required this.username,
    required this.animationDuration,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: animationDuration,
      curve: Curves.easeOutCubic,
      left: offset.dx,
      top: offset.dy,
      child: _CursorLabel(
        lineHeight: lineHeight,
        color: color,
        username: username,
      ),
    );
  }
}

/// The visual cursor line and user name label.
class _CursorLabel extends StatelessWidget {
  final double lineHeight;
  final Color color;
  final String username;

  const _CursorLabel({
    required this.lineHeight,
    required this.color,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: username,
      preferBelow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cursor line.
          Container(
            width: 2.0,
            height: lineHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.0),
            ),
          ),
          // User avatar label above the cursor.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
            child: Text(
              username,
              style: TextStyle(
                fontSize: 10,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
