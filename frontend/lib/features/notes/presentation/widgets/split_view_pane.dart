import 'package:flutter/material.dart';

/// A horizontal split pane with a draggable divider between two child widgets.
///
/// Used for side-by-side editing of two notes on wide screens. The divider
/// can be dragged to resize the panes. Each pane has a minimum width of
/// [_kMinPaneWidth] pixels.
///
/// The [onClose] callback is invoked when the user presses the close button
/// on the secondary (right) pane header.
class SplitViewPane extends StatefulWidget {
  /// The primary (left) child widget.
  final Widget primaryChild;

  /// The secondary (right) child widget.
  final Widget secondaryChild;

  /// Title displayed in the secondary pane header.
  final String secondaryTitle;

  /// Called when the close button is pressed on the secondary pane.
  final VoidCallback onClose;

  /// Initial fraction of total width allocated to the primary pane (0.0-1.0).
  /// Defaults to 0.5 (50/50 split).
  final double initialRatio;

  const SplitViewPane({
    super.key,
    required this.primaryChild,
    required this.secondaryChild,
    required this.secondaryTitle,
    required this.onClose,
    this.initialRatio = 0.5,
  });

  @override
  State<SplitViewPane> createState() => _SplitViewPaneState();
}

class _SplitViewPaneState extends State<SplitViewPane> {
  late double _ratio;

  /// Minimum width per pane in pixels.
  static const double _kMinPaneWidth = 300.0;

  /// Width of the draggable divider.
  static const double _kDividerWidth = 8.0;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio.clamp(0.2, 0.8);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final minRatio = _kMinPaneWidth / totalWidth;
        final maxRatio = 1.0 - minRatio;

        final primaryWidth = (totalWidth * _ratio).clamp(
          _kMinPaneWidth,
          totalWidth - _kMinPaneWidth - _kDividerWidth,
        );
        final secondaryWidth = totalWidth - primaryWidth - _kDividerWidth;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Primary pane
            SizedBox(
              width: primaryWidth,
              child: widget.primaryChild,
            ),

            // Draggable divider
            _SplitDivider(
              onDrag: (delta) {
                setState(() {
                  final deltaRatio = delta / totalWidth;
                  _ratio = (_ratio + deltaRatio).clamp(minRatio, maxRatio);
                });
              },
            ),

            // Secondary pane
            SizedBox(
              width: secondaryWidth,
              child: Column(
                children: [
                  // Secondary pane header with title and close button
                  _SecondaryPaneHeader(
                    title: widget.secondaryTitle,
                    onClose: widget.onClose,
                  ),
                  const Divider(height: 1),
                  // Secondary content
                  Expanded(child: widget.secondaryChild),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Header bar for the secondary pane showing the note title and a close button.
class _SecondaryPaneHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _SecondaryPaneHeader({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close split view',
            onPressed: onClose,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// Vertical draggable divider between the two panes.
class _SplitDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;

  const _SplitDivider({required this.onDrag});

  @override
  State<_SplitDivider> createState() => _SplitDividerState();
}

class _SplitDividerState extends State<_SplitDivider> {
  double _lastX = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        _lastX = details.globalPosition.dx;
      },
      onHorizontalDragUpdate: (details) {
        final dx = details.globalPosition.dx - _lastX;
        _lastX = details.globalPosition.dx;
        widget.onDrag(dx);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 8,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          child: Center(
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
