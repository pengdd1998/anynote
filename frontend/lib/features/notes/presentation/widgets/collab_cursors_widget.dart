import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/collab/cursor_overlay.dart';
import '../../../../core/collab/ws_client.dart';

/// Widget that integrates collaboration cursor rendering over the editor.
///
/// Wrap the editor widget with this to display remote collaborator cursors.
/// The widget obtains the editor's [RenderBox] on each frame for precise
/// cursor positioning and passes it to [CursorOverlay].
class CollabCursorsWidget extends ConsumerStatefulWidget {
  final String noteId;
  final Widget child;

  /// Optional editor content string used for fallback heuristic positioning.
  final String editorContent;

  const CollabCursorsWidget({
    super.key,
    required this.noteId,
    required this.child,
    this.editorContent = '',
  });

  @override
  ConsumerState<CollabCursorsWidget> createState() =>
      _CollabCursorsWidgetState();
}

class _CollabCursorsWidgetState extends ConsumerState<CollabCursorsWidget> {
  final List<CursorData> _cursors = [];
  StreamSubscription<dynamic>? _subscription;
  RenderBox? _editorBox;
  final GlobalKey _editorKey = GlobalKey();

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

  /// Obtain the editor's RenderBox from the child widget tree.
  RenderBox? _findEditorBox() {
    try {
      final renderObject = _editorKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        return renderObject;
      }
    } catch (e) {
      // RenderObject may not be available during frame transitions.
      debugPrint('[CollabCursorsWidget] failed to find editor RenderBox: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Use a post-frame callback to capture the editor's RenderBox after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _findEditorBox();
      if (box != _editorBox) {
        setState(() {
          _editorBox = box;
        });
      }
    });

    return Stack(
      children: [
        // Wrap the child with a key so we can find its RenderBox.
        KeyedSubtree(
          key: _editorKey,
          child: widget.child,
        ),
        Positioned.fill(
          child: CursorOverlay(
            cursors: _cursors,
            content: widget.editorContent,
            editorBox: _editorBox,
            lineHeight: 20.0,
            fontSize: 14.0,
            horizontalPadding: 16.0,
          ),
        ),
      ],
    );
  }
}
