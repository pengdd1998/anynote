import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_durations.dart';

/// Key used for persisting the master pane width.
const _kMasterWidthKey = 'master_detail_divider_width';

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
/// lets the user resize the master pane width. The divider position is
/// persisted across sessions via SharedPreferences.
///
/// The sidebar can be collapsed/expanded with smooth animation. This is
/// controlled by the [sidebarVisible] parameter, typically wired to the
/// [sidebarVisibleProvider].
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
  /// Deprecated in favor of [placeholderBuilder] which provides localization
  /// context via [BuildContext].
  final Widget? emptyDetailPlaceholder;

  /// Optional builder for the placeholder shown in the detail pane when no
  /// item is selected. Receives a [BuildContext] so the placeholder can use
  /// localization and theming.
  ///
  /// If both [emptyDetailPlaceholder] and [placeholderBuilder] are provided,
  /// [placeholderBuilder] takes precedence.
  final Widget Function(BuildContext context)? placeholderBuilder;

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

  /// Whether the sidebar (master pane) is currently visible.
  /// When false, the master pane collapses with an animation.
  final bool sidebarVisible;

  /// Text shown in the default placeholder when no item is selected.
  /// Defaults to 'Select an item to view' but can be overridden with
  /// a localized string.
  final String placeholderText;

  const MasterDetailLayout({
    super.key,
    required this.masterPane,
    required this.detailPaneBuilder,
    this.emptyDetailPlaceholder,
    this.placeholderBuilder,
    this.selectedId,
    this.onSelectionChanged,
    this.masterPaneWidth = 350,
    this.masterPaneMinWidth = 250,
    this.masterPaneMaxWidth = 500,
    this.sideBySideThreshold = 600,
    this.sidebarVisible = true,
    this.placeholderText = 'Select an item to view',
  });

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

class _MasterDetailLayoutState extends State<MasterDetailLayout> {
  late double _masterWidth;
  Timer? _persistTimer;

  @override
  void initState() {
    super.initState();
    _masterWidth = widget.masterPaneWidth;
    _loadPersistedWidth();
  }

  @override
  void didUpdateWidget(MasterDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.masterPaneWidth != widget.masterPaneWidth) {
      _masterWidth = widget.masterPaneWidth;
    }
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }

  /// Load previously saved divider position from SharedPreferences.
  Future<void> _loadPersistedWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_kMasterWidthKey);
    if (saved != null &&
        saved >= widget.masterPaneMinWidth &&
        saved <= widget.masterPaneMaxWidth) {
      if (mounted) {
        setState(() => _masterWidth = saved);
      }
    }
  }

  /// Persist the divider position with a debounce to avoid excessive writes.
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kMasterWidthKey, _masterWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useSideBySide = screenWidth >= widget.sideBySideThreshold;

    if (!useSideBySide) {
      // Phone layout: only show the master pane.
      return widget.masterPane;
    }

    // Desktop/tablet layout: side-by-side with animated sidebar.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Animated master pane
        AnimatedContainer(
          duration: AppDurations.shortAnimation,
          curve: Curves.easeInOut,
          width: widget.sidebarVisible ? _masterWidth : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: widget.sidebarVisible
              ? widget.masterPane
              : const SizedBox.shrink(),
        ),
        // Draggable divider (only visible when sidebar is expanded)
        if (widget.sidebarVisible)
          _DraggableDivider(
            onDrag: (delta) {
              setState(() {
                _masterWidth = (_masterWidth + delta).clamp(
                  widget.masterPaneMinWidth,
                  widget.masterPaneMaxWidth,
                );
              });
              _schedulePersist();
            },
          ),
        // Detail pane
        Expanded(
          child: widget.selectedId != null
              ? widget.detailPaneBuilder(widget.selectedId)
              : widget.placeholderBuilder != null
                  ? widget.placeholderBuilder!(context)
                  : widget.emptyDetailPlaceholder ??
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.placeholderText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.7),
                                  ),
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
          width: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
