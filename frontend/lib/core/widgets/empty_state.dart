import 'package:flutter/material.dart';

/// A reusable empty state widget displayed when a list has no items.
///
/// Shows a large icon, a title, an optional subtitle, and an optional action
/// button. Designed to be placed inside a scrollable area or as the direct
/// child of a `Center` widget.
///
/// Usage:
/// ```dart
/// EmptyState(
///   icon: Icons.note_add,
///   title: 'No notes yet',
///   subtitle: 'Create your first note',
///   actionLabel: 'New Note',
///   onAction: () => context.push('/notes/new'),
/// )
/// ```
class EmptyState extends StatelessWidget {
  /// Large icon displayed above the title.
  final IconData icon;

  /// Primary message (e.g. "No notes yet").
  final String title;

  /// Secondary explanation (e.g. "Create your first note").
  final String? subtitle;

  /// Label for the optional CTA button.
  final String? actionLabel;

  /// Callback when the CTA button is pressed.
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
