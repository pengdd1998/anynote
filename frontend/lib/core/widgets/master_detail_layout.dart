import 'package:flutter/material.dart';

/// A two-pane master-detail layout that adapts to screen size.
///
/// On desktop/tablet (width >= 600) the widget shows a side-by-side layout:
/// - Left pane (master): typically a list of items
/// - Right pane (detail): the content of the selected item
///
/// On phone (width < 600) only the master pane is shown. Tapping an item
/// should navigate to a separate detail screen.
///
/// The layout includes a draggable divider between the panes on desktop that
/// lets the user resize the master pane width.
///
/// Usage:
/// ```dart
/// MasterDetailLayout(
///   masterPane: NotesList(),
///   detailPaneBuilder: (selectedId) => NoteDetail(id: selectedId),
///   selectedId: _selectedNoteId,
///   onSelectionChanged: (id) => setState(() => _selectedNoteId = id),
/// )
/// ```
class MasterDetailLayout extends StatefulWidget {
  /// The widget displayed in the left (master) pane.
  final Widget masterPane;

  /// Builder for the right (detail) pane. Called with the currently selected
  /// item ID or null if nothing is selected.
  final Widget Function(String? selectedId) detailPaneBuilder;

  /// Optional placeholder shown in the detail pane when no item is selected.
  final Widget? emptyDetailPlaceholder;

  /// The ID of the currently selected item, or null.
  final String? selectedId;

  /// Callback invoked when the user selects an item in the master pane.
  /// The MasterDetailLayout itself does not handle taps -- the master pane
  /// widget should call this callback when an item is tapped.
  final ValueChanged<String?>? onSelectionChanged;

  /// Initial width of the master pane. Defaults to 350.
  final double masterPaneWidth;

  /// Minimum width the master pane can be dragged to. Defaults to 250.
  final double masterPaneMinWidth;

  /// Maximum width the master pane can be dragged to. Defaults to 500.
  final double masterPaneMaxWidth;

  /// Width threshold above which the side-by-side layout is used.
  /// Below this threshold only the master pane is shown. Defaults to 600.
  final double sideBySideThreshold;

  const MasterDetailLayout({
    super.key,
    required this.masterPane,
    required this.detailPaneBuilder,
    this.emptyDetailPlaceholder,
    this.selectedId,
    this.onSelectionChanged,
    this.masterPaneWidth = 350,
    this.masterPaneMinWidth = 250,
    this.masterPaneMaxWidth = 500,
    this.sideBySideThreshold = 600,
  });

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  late double _masterWidth;

  @override
  void initState() {
    super.initState();
    _masterWidth = widget.masterPaneWidth;
  }

  @override
  void didUpdateWidget(MasterDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.masterPaneWidth != widget.masterPaneWidth) {
      _masterWidth = widget.masterPaneWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useSideBySide = screenWidth >= widget.sideBySideThreshold;

    if (!useSideBySide) {
      // Phone layout: only show the master pane.
      return widget.masterPane;
    }

    // Desktop/tablet layout: side-by-side with draggable divider.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master pane
        SizedBox(
          width: _masterWidth,
          child: widget.masterPane,
        ),
        // Draggable divider
        _DraggableDivider(
          onDrag: (delta) {
            setState(() {
              _masterWidth = (_masterWidth + delta)
                  .clamp(widget.masterPaneMinWidth, widget.masterPaneMaxWidth);
            });
          },
        ),
        // Detail pane
        Expanded(
          child: widget.selectedId != null
              ? widget.detailPaneBuilder(widget.selectedId)
              : widget.emptyDetailPlaceholder ??
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select an item to view',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }
}

/// A thin vertical divider that the user can drag left/right to resize the
/// master pane.
class _DraggableDivider extends StatefulWidget {
  final ValueChanged<double> onDrag;

  const _DraggableDivider({required this.onDrag});

  @override
  State<_DraggableDivider> createState() => _DraggableDividerState();
}

class _DraggableDividerState extends State<_DraggableDivider> {
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
          width: 1,
          color: Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}
