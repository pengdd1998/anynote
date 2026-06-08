import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presence_indicator.dart';

/// A single remote user's cursor position in the editor.
class RemoteCursor {
  final String userId;
  final String displayName;
  final int position;

  const RemoteCursor({
    required this.userId,
    required this.displayName,
    required this.position,
  });
}

/// Overlay that renders remote user cursors on top of the editor.
///
/// Each cursor is a thin vertical line with a small label showing the
/// user's display name. Colors are derived from the user ID using the
/// same palette as [PresenceAvatarStack].
class RemoteCursorOverlay extends ConsumerWidget {

  /// Deterministic color derived from the user ID.
  /// Matches the palette used in PresenceAvatarStack.
  static Color colorForUserId(String userId) {
    var hash = 0;
    for (var i = 0; i < userId.length; i++) {
      hash = (hash * 31 + userId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    const palette = [
      Color(0xFF6750A4),
      Color(0xFFE91E63),
      Color(0xFF009688),
      Color(0xFFFF9800),
      Color(0xFF2196F3),
      Color(0xFF4CAF50),
      Color(0xFFF44336),
      Color(0xFF3F51B5),
      Color(0xFF00BCD4),
      Color(0xFF8BC34A),
    ];
    return palette[hash % palette.length];
  }
  final List<RemoteCursor> cursors;
  final double lineHeight;
  final double charWidth;
  final int linesPerRow;
  final EdgeInsets padding;

  const RemoteCursorOverlay({
    super.key,
    required this.cursors,
    this.lineHeight = 20,
    this.charWidth = 8,
    this.linesPerRow = 80,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cursors.isEmpty) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: cursors.map((cursor) {
        final offset = _positionToOffset(cursor.position);
        final color = RemoteCursorOverlay.colorForUserId(cursor.userId);

        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: _CursorWidget(
            color: color,
            label: cursor.displayName,
            lineHeight: lineHeight,
          ),
        );
      }).toList(),
    );
  }

  /// Convert a character position to a 2D offset.
  Offset _positionToOffset(int position) {
    final row = position ~/ linesPerRow;
    final col = position % linesPerRow;
    return Offset(
      padding.left + col * charWidth,
      padding.top + row * lineHeight,
    );
  }
}

/// A single cursor widget: a thin vertical line with a name label.
class _CursorWidget extends StatefulWidget {
  final Color color;
  final String label;
  final double lineHeight;

  const _CursorWidget({
    required this.color,
    required this.label,
    required this.lineHeight,
  });

  @override
  State<_CursorWidget> createState() => _CursorWidgetState();
}

class _CursorWidgetState extends State<_CursorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.5 + 0.5 * _controller.value;
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name label above the cursor line.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Cursor line.
          Container(
            width: 2,
            height: widget.lineHeight,
            color: widget.color,
          ),
        ],
      ),
    );
  }
}
