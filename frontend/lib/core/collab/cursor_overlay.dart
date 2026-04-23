import 'package:flutter/material.dart';

/// Data model for a remote collaborator's cursor position.
class CursorData {
  final String userId;
  final String username;
  final int position;
  final Color color;

  const CursorData({
    required this.userId,
    required this.username,
    required this.position,
    required this.color,
  });

  factory CursorData.fromMap(Map<String, dynamic> map) {
    return CursorData(
      userId: map['user_id'] as String? ?? '',
      username: map['username'] as String? ?? '???',
      position: map['position'] as int? ?? 0,
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
}

/// Overlay widget that renders remote collaborator cursors.
/// This is positioned over the editor area.
class CursorOverlay extends StatelessWidget {
  final List<CursorData> cursors;

  const CursorOverlay({super.key, required this.cursors});

  @override
  Widget build(BuildContext context) {
    if (cursors.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: cursors.map((cursor) {
        // Approximate cursor Y position from character offset.
        // In a real integration, this would use the editor's render box.
        final lineHeight = 20.0;
        final charsPerLine = 40;
        final line = cursor.position ~/ charsPerLine;
        final yOffset = line * lineHeight;

        return Positioned(
          left: 8,
          top: yOffset,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: lineHeight,
                color: cursor.color,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cursor.color,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  cursor.username,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
