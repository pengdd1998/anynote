import 'package:flutter/material.dart';

/// A focus-mode overlay that dims content outside the current line and
/// highlights the line at the cursor position.
///
/// This widget wraps a child (the editor) and applies a gradient overlay that
/// creates a spotlight effect around the vertical center of the visible area.
/// When [isActive] is false, the overlay is transparent.
///
/// The spotlight approach is used instead of per-line dimming because
/// flutter_quill does not expose line-level render objects for direct
/// manipulation.
class FocusHighlight extends StatelessWidget {
  /// Whether focus highlighting is currently active.
  final bool isActive;

  /// The editor widget to wrap with the focus overlay.
  final Widget child;

  const FocusHighlight({
    super.key,
    required this.isActive,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isActive) return child;

    return Stack(
      children: [
        child,
        // Overlay that dims everything except a horizontal band near the
        // center of the visible area. The band represents the "current line"
        // spotlight.
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FocusSpotlightPainter(
                  spotlightHeight: 48.0,
                  dimColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF000000).withValues(alpha: 0.35)
                      : const Color(0xFFFFFFFF).withValues(alpha: 0.4),
                  highlightColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.04),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that creates a vertical gradient with a transparent band
/// (the spotlight) near the vertical center and dimmed regions above and below.
class _FocusSpotlightPainter extends CustomPainter {
  /// Height of the transparent spotlight band in logical pixels.
  final double spotlightHeight;

  /// Color used for the dimmed regions above and below the spotlight.
  final Color dimColor;

  /// Subtle highlight color applied to the spotlight band.
  final Color highlightColor;

  _FocusSpotlightPainter({
    required this.spotlightHeight,
    required this.dimColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final centerY =
        size.height * 0.45; // slightly above center (reading position)
    final halfSpot = spotlightHeight / 2;

    // Top dim region: from top to start of spotlight.
    final topRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      (centerY - halfSpot).clamp(0.0, size.height),
    );
    if (topRect.height > 0) {
      final topPaint = Paint()..color = dimColor;
      canvas.drawRect(topRect, topPaint);
    }

    // Spotlight band: subtle highlight background.
    final spotlightRect = Rect.fromLTWH(
      0,
      (centerY - halfSpot).clamp(0.0, size.height),
      size.width,
      spotlightHeight,
    );
    final highlightPaint = Paint()..color = highlightColor;
    canvas.drawRect(spotlightRect, highlightPaint);

    // Bottom dim region: from end of spotlight to bottom.
    final bottomStart = (centerY + halfSpot).clamp(0.0, size.height);
    final bottomRect = Rect.fromLTWH(
      0,
      bottomStart,
      size.width,
      (size.height - bottomStart).clamp(0.0, size.height),
    );
    if (bottomRect.height > 0) {
      final bottomPaint = Paint()..color = dimColor;
      canvas.drawRect(bottomRect, bottomPaint);
    }

    // Gradient transitions at the spotlight edges for a smooth blend.
    _drawGradientEdge(canvas, size, centerY - halfSpot, true);
    _drawGradientEdge(canvas, size, centerY + halfSpot, false);
  }

  /// Draw a soft gradient at the edge of the spotlight band.
  void _drawGradientEdge(Canvas canvas, Size size, double y, bool isTopEdge) {
    const gradientHeight = 20.0;
    final gradientRect = Rect.fromLTWH(
      0,
      isTopEdge ? (y - gradientHeight).clamp(0.0, size.height) : y,
      size.width,
      gradientHeight,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: isTopEdge ? Alignment.topCenter : Alignment.bottomCenter,
        end: isTopEdge ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [
          dimColor,
          dimColor.withValues(alpha: 0.0),
        ],
      ).createShader(gradientRect);

    canvas.drawRect(gradientRect, paint);
  }

  @override
  bool shouldRepaint(covariant _FocusSpotlightPainter oldDelegate) {
    return oldDelegate.spotlightHeight != spotlightHeight ||
        oldDelegate.dimColor != dimColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
