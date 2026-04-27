import 'package:flutter/material.dart';

/// Wraps a widget tree in a [FocusTraversalGroup] with
/// [OrderedTraversalPolicy], establishing a logical tab order:
/// top bar, then content, then bottom bar.
///
/// Usage:
/// ```dart
/// SemanticOrder(
///   child: Column(
///     children: [
///       FocusTraversalOrder(order: const NumericFocusOrder(0), child: appBar),
///       Expanded(
///         child: FocusTraversalOrder(order: const NumericFocusOrder(1), child: body),
///       ),
///       FocusTraversalOrder(order: const NumericFocusOrder(2), child: bottomBar),
///     ],
///   ),
/// )
/// ```
class SemanticOrder extends StatelessWidget {
  final Widget child;

  const SemanticOrder({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: child,
    );
  }
}

/// Convenience wrapper that assigns a [NumericFocusOrder] to a child widget.
/// Use inside a [SemanticOrder] parent to establish tab sequence.
class SemanticOrderSlot extends StatelessWidget {
  final double order;
  final Widget child;

  const SemanticOrderSlot({
    super.key,
    required this.order,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: child,
    );
  }
}
