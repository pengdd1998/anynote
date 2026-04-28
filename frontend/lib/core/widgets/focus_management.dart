import 'package:flutter/material.dart';

import '../platform/platform_utils.dart';

/// Manages a ring of [FocusNode]s for sequential tab navigation on desktop.
///
/// Desktop users expect Tab/Shift+Tab to cycle through input fields and
/// interactive elements in a predictable order. This utility manages a
/// list of [FocusNode]s and provides methods to request focus on the next
/// or previous node in the ring.
///
/// Create one instance per form or screen, add focus nodes for each field
/// in tab order, and call [dispose] when the widget is unmounted.
///
/// Usage:
/// ```dart
/// class _MyFormState extends State<MyForm> {
///   final _focusRing = FocusRing();
///
///   @override
///   void initState() {
///     super.initState();
///     _focusRing.addAll([titleNode, bodyNode, tagNode]);
///   }
///
///   @override
///   void dispose() {
///     _focusRing.dispose();
///     super.dispose();
///   }
/// }
/// ```
class FocusRing {
  final List<FocusNode> _nodes = [];

  /// The number of focus nodes in the ring.
  int get length => _nodes.length;

  /// Whether the ring is empty.
  bool get isEmpty => _nodes.isEmpty;

  /// Add a single [FocusNode] to the end of the ring.
  void add(FocusNode node) {
    _nodes.add(node);
  }

  /// Add multiple [FocusNode]s to the end of the ring, in order.
  void addAll(List<FocusNode> nodes) {
    _nodes.addAll(nodes);
  }

  /// Remove a specific [FocusNode] from the ring.
  void remove(FocusNode node) {
    _nodes.remove(node);
  }

  /// Request focus on the next node in the ring after [current].
  ///
  /// If [current] is null or not in the ring, focuses the first node.
  /// Wraps around from the last node back to the first.
  void focusNext(FocusNode? current) {
    if (_nodes.isEmpty) return;
    if (!PlatformUtils.isDesktop) return;

    final index = current != null ? _nodes.indexOf(current) : -1;
    final nextIndex = (index + 1) % _nodes.length;
    _nodes[nextIndex].requestFocus();
  }

  /// Request focus on the previous node in the ring before [current].
  ///
  /// If [current] is null or not in the ring, focuses the last node.
  /// Wraps around from the first node back to the last.
  void focusPrevious(FocusNode? current) {
    if (_nodes.isEmpty) return;
    if (!PlatformUtils.isDesktop) return;

    final index = current != null ? _nodes.indexOf(current) : 0;
    final prevIndex = (index - 1 + _nodes.length) % _nodes.length;
    _nodes[prevIndex].requestFocus();
  }

  /// Request focus on the first node in the ring.
  void focusFirst() {
    if (_nodes.isEmpty) return;
    _nodes.first.requestFocus();
  }

  /// Request focus on the last node in the ring.
  void focusLast() {
    if (_nodes.isEmpty) return;
    _nodes.last.requestFocus();
  }

  /// Returns the [FocusNode] at [index], or null if out of bounds.
  FocusNode? operator [](int index) {
    if (index < 0 || index >= _nodes.length) return null;
    return _nodes[index];
  }

  /// Unfocus all nodes in the ring (hides the keyboard on mobile).
  void unfocus() {
    for (final node in _nodes) {
      node.unfocus();
    }
  }

  /// Dispose all managed [FocusNode]s. Call in the widget's [dispose] method.
  ///
  /// Only disposes nodes that were created by this ring (via [createNode]).
  /// Nodes added via [add] or [addAll] are the caller's responsibility.
  void dispose() {
    for (final node in _managedNodes) {
      node.dispose();
    }
    _managedNodes.clear();
    _nodes.clear();
  }

  final List<FocusNode> _managedNodes = [];

  /// Create a new [FocusNode] that is automatically tracked and will be
  /// disposed when [dispose] is called. Returns the created node.
  ///
  /// Use this for nodes whose lifecycle is owned by the [FocusRing].
  FocusNode createNode([String? debugLabel]) {
    final node = FocusNode(debugLabel: debugLabel);
    _nodes.add(node);
    _managedNodes.add(node);
    return node;
  }
}
