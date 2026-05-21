import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A standardized bottom sheet with drag handle and warm design styling.
///
/// Wraps `showModalBottomSheet` with consistent radius, background color,
/// and a built-in drag handle. Content is wrapped in `SafeArea` by default.
///
/// ```dart
/// ModalSheet.show(
///   context: context,
///   title: 'Choose option',
///   builder: (context) => Column(children: [...]),
/// )
/// ```
class ModalSheet {
  ModalSheet._();

  /// Shows a styled modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    bool showHandle = true,
    Color? backgroundColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: true,
      backgroundColor:
          backgroundColor ?? _cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.topXl,
      ),
      builder: (sheetContext) => _SheetContent(
        title: title,
        showHandle: showHandle,
        child: builder(sheetContext),
      ),
    );
  }

  static Color _cardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkCardBg : AppColors.lightCardBg;
  }
}

class _SheetContent extends StatelessWidget {
  final String? title;
  final bool showHandle;
  final Widget child;

  const _SheetContent({
    this.title,
    required this.showHandle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) _DragHandle(),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.s4,
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
