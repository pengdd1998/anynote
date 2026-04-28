import 'package:flutter/material.dart';

import '../platform/platform_utils.dart';

/// A wrapper that provides a desktop-style context menu on right-click
/// (secondary tap). On mobile platforms the child is rendered without
/// any wrapper.
///
/// Usage:
/// ```dart
/// DesktopContextMenu(
///   items: [
///     PopupMenuItem(value: 'copy', child: Text('Copy')),
///     PopupMenuItem(value: 'paste', child: Text('Paste')),
///   ],
///   onSelected: (value) => handleAction(value),
///   child: Text('Right-click me'),
/// )
/// ```
class DesktopContextMenu extends StatelessWidget {
  /// The widget that triggers the context menu on right-click.
  final Widget child;

  /// The menu items to display in the context menu.
  final List<PopupMenuEntry<String>> items;

  /// Callback when a menu item is selected.
  final void Function(String value)? onSelected;

  const DesktopContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // On mobile, just render the child without context menu support.
    if (!PlatformUtils.isDesktop) return child;

    return GestureDetector(
      onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
      // Also support long-press as a fallback on desktop touchscreens.
      onLongPressStart: (details) => _showMenu(context, details.globalPosition),
      child: child,
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final menuPosition = RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: menuPosition,
      items: items,
    ).then((value) {
      if (value != null && onSelected != null) {
        onSelected!(value);
      }
    });
  }
}
