import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/collab/cursor_overlay.dart';
import '../../../../core/collab/ws_client.dart';

/// Widget that integrates collaboration cursor rendering over the editor.
class CollabCursorsWidget extends ConsumerStatefulWidget {
  final String noteId;
  final Widget child;

  const CollabCursorsWidget({
    super.key,
    required this.noteId,
    required this.child,
  });

  @override
  ConsumerState<CollabCursorsWidget> createState() =>
      _CollabCursorsWidgetState();
}

class _CollabCursorsWidgetState extends ConsumerState<CollabCursorsWidget> {
  final List<CursorData> _cursors = [];
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _listenForCursors();
  }

  void _listenForCursors() {
    final wsNotifier = ref.read(wsClientProvider.notifier);
    final client = wsNotifier.client;
    _subscription = client.messages.listen((msg) {
      if (msg.type == WSMessageType.cursor && mounted) {
        final room = msg.data['room'] as String?;
        if (room == widget.noteId) {
          setState(() {
            // Remove existing cursor for this user, then add updated one.
            final newCursor = CursorData.fromMap(msg.data);
            _cursors.removeWhere((c) => c.userId == newCursor.userId);
            _cursors.add(newCursor);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: CursorOverlay(cursors: _cursors),
        ),
      ],
    );
  }
}
