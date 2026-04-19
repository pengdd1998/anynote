import 'dart:math';

import 'package:flutter/material.dart';

/// Accessibility utility helpers for the AnyNote app.
///
/// Provides semantic label generators, touch target enforcement, and contrast
/// ratio calculation for building accessible UI components.
class A11yUtils {
  A11yUtils._();

  // ---------------------------------------------------------------------------
  // Touch target helpers
  // ---------------------------------------------------------------------------

  /// Ensure minimum touch target size (48x48 dp per Material guidelines).
  ///
  /// Wraps [child] in a [SizedBox] constrained to at least [minSize] in both
  /// dimensions, centered within the box.
  static Widget ensureTouchTarget({
    required Widget child,
    double minSize = 48.0,
  }) {
    return SizedBox(
      width: minSize,
      height: minSize,
      child: Center(child: child),
    );
  }

  /// Enforce a minimum tap target size using [ConstrainedBox].
  ///
  /// Unlike [ensureTouchTarget], this does not force the size to exactly
  /// [minSize] -- it only guarantees the widget is at least that large.
  /// Useful when the child already has an intrinsic size but may be too small.
  ///
  /// Returns the same [child] wrapped in a [ConstrainedBox] with
  /// [BoxConstraints.minWidth] and [BoxConstraints.minHeight] set to
  /// [minSize], centered vertically and horizontally.
  static Widget ensureMinTouchSize({
    required Widget child,
    double minSize = 48.0,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: Center(child: child),
    );
  }

  // ---------------------------------------------------------------------------
  // Semantic label generators
  // ---------------------------------------------------------------------------

  /// Build a semantic label for a note card used in lists and grids.
  ///
  /// Returns a human-readable string like
  /// "Note: Shopping list, updated 2h ago, pinned".
  static String noteCardLabel({
    required String title,
    required String timeDescription,
    bool isPinned = false,
    bool isSynced = true,
  }) {
    final parts = <String>['Note: $title'];
    if (isPinned) parts.add('pinned');
    if (!isSynced) parts.add('not synced');
    parts.add('updated $timeDescription');
    return parts.join(', ');
  }

  /// Build a semantic label for a note that includes a preview snippet.
  ///
  /// [title] is the note title (or fallback "Untitled").
  /// [preview] is a short content preview (first ~100 chars).
  /// [date] is a human-readable date or relative time string.
  ///
  /// Returns something like:
  /// "Shopping list. Preview: Milk, eggs, bread... Updated 2 hours ago."
  static String semanticLabelForNote({
    required String title,
    String? preview,
    String? date,
  }) {
    final parts = <String>[title];
    if (preview != null && preview.isNotEmpty) {
      parts.add('Preview: $preview');
    }
    if (date != null && date.isNotEmpty) {
      parts.add('Updated $date');
    }
    return parts.join('. ');
  }

  /// Build a semantic label for a tag chip.
  ///
  /// [name] is the tag display name.
  /// [count] is the optional number of notes with this tag.
  ///
  /// Returns something like "Tag: Work, 12 notes" or "Tag: Personal".
  static String semanticLabelForTag({
    required String name,
    int? count,
  }) {
    if (count != null && count > 0) {
      return 'Tag: $name, $count notes';
    }
    return 'Tag: $name';
  }

  // ---------------------------------------------------------------------------
  // Semantic widget wrappers
  // ---------------------------------------------------------------------------

  /// Wraps a button with a semantic label for screen readers.
  ///
  /// Use this for buttons where the visual label may not be sufficient
  /// for screen reader users, or where the button uses only an icon.
  static Widget labeledButton({
    required String label,
    required Widget child,
    Key? key,
  }) {
    return Semantics(
      key: key,
      button: true,
      label: label,
      child: child,
    );
  }

  /// Wraps an icon with a semantic label for screen readers.
  ///
  /// Use this for standalone icons that convey meaning but have no
  /// accompanying text. Decorative icons should use [ExcludeSemantics]
  /// instead.
  static Widget labeledIcon({
    required String label,
    required Widget child,
    Key? key,
  }) {
    return Semantics(
      key: key,
      label: label,
      child: child,
    );
  }

  /// Wraps a text field with a semantic label for screen readers.
  ///
  /// Ensures the field's purpose is announced even when the visual label
  /// is in a separate widget (e.g., a label above the field).
  static Widget labeledTextField({
    required String label,
    required Widget child,
    String? hint,
    Key? key,
  }) {
    return Semantics(
      key: key,
      label: label,
      hint: hint,
      textField: true,
      child: child,
    );
  }

  /// Wraps a card with [MergeSemantics] so screen readers announce the
  /// entire card as a single unit rather than individual elements.
  ///
  /// Use for list/grid items where the card contains multiple text elements
  /// (title, subtitle, metadata) that should be read together.
  static Widget semanticCard({
    required String label,
    required Widget child,
    bool isButton = true,
    Key? key,
  }) {
    return MergeSemantics(
      child: Semantics(
        key: key,
        button: isButton,
        label: label,
        child: child,
      ),
    );
  }

  /// Create a semantic button wrapper for custom tappable areas.
  ///
  /// Use this for gesture-detector-based buttons that are not Material
  /// [IconButton] or [TextButton] widgets, so screen readers announce them
  /// correctly.
  static Widget semanticButton({
    required String label,
    required Widget child,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(onTap: enabled ? onTap : null, child: child),
    );
  }

  /// Alias for [ensureTouchTarget] for API consistency.
  static Widget touchTarget({
    required Widget child,
    double minSize = 48.0,
  }) {
    return ensureTouchTarget(child: child, minSize: minSize);
  }

  // ---------------------------------------------------------------------------
  // Color contrast utilities
  // ---------------------------------------------------------------------------

  /// Calculate the WCAG 2.0 contrast ratio between two colors.
  ///
  /// Returns a value between 1.0 (no contrast) and 21.0 (maximum contrast).
  /// WCAG AA requires at least 4.5:1 for normal text and 3.0:1 for large text.
  ///
  /// Example:
  /// ```dart
  /// final ratio = A11yUtils.contrastRatio(Colors.black, Colors.white);
  /// // ratio == 21.0
  /// ```
  static double contrastRatio(Color a, Color b) {
    final luminanceA = _relativeLuminance(a);
    final luminanceB = _relativeLuminance(b);
    final lighter = max(luminanceA, luminanceB);
    final darker = min(luminanceA, luminanceB);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Returns true if the contrast ratio between [foreground] and [background]
  /// meets the WCAG AA threshold for normal text (4.5:1).
  static bool meetsWcagAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 4.5;
  }

  /// Checks whether the contrast ratio between [foreground] and [background]
  /// meets WCAG 2.1 Level AA requirements.
  ///
  /// Normal text (font size < 18pt, or < 14pt bold) requires 4.5:1.
  /// Large text (font size >= 18pt, or >= 14pt bold) requires 3:1.
  ///
  /// Set [isLargeText] to true when evaluating large text (headings, display
  /// text). Defaults to false (normal text threshold).
  static bool meetsAA({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final ratio = contrastRatio(foreground, background);
    final threshold = isLargeText ? 3.0 : 4.5;
    return ratio >= threshold;
  }

  /// Returns true if the contrast ratio between [foreground] and [background]
  /// meets the WCAG AA threshold for large text (3.0:1).
  static bool meetsWcagAALarge(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 3.0;
  }

  /// Compute the WCAG 2.0 relative luminance of a color.
  ///
  /// Uses the standard formula:
  /// L = 0.2126 * R + 0.7152 * G + 0.0722 * B
  /// where R, G, B are linearized from sRGB.
  static double _relativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize a single sRGB channel value (0.0--1.0) for luminance
  /// calculation per WCAG 2.0 specification.
  static double _linearize(double channel) {
    if (channel <= 0.04045) {
      return channel / 12.92;
    }
    return pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Composite a foreground color with transparency over an opaque background.
  ///
  /// This is needed for calculating the effective contrast of colors that use
  /// `withAlpha()` or `withOpacity()`. Returns the resulting opaque color.
  static Color compositeColor(Color foreground, Color background) {
    final alpha = foreground.a;
    final r = (foreground.r * alpha + background.r * (1 - alpha)).clamp(0.0, 1.0);
    final g = (foreground.g * alpha + background.g * (1 - alpha)).clamp(0.0, 1.0);
    final b = (foreground.b * alpha + background.b * (1 - alpha)).clamp(0.0, 1.0);
    return Color.from(alpha: 1.0, red: r, green: g, blue: b);
  }
}
