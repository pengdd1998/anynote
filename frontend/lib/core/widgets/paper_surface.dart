import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/paper_tokens.dart';
import 'paper_doodle.dart';

/// A sheet of sticky-note paper — the reusable skeuomorphic surface
/// extracted from the notes home mockup.
///
/// Applies the [PaperTokens] theme extension: saturated paper tone, small
/// Post-it radius, warm two-layer shadow, no border, and a slight
/// hand-placed tilt. Use it anywhere content should read as "written on
/// paper" (note cards, collection covers, compose cluster picks, banners):
///
/// ```dart
/// PaperSurface(
///   seed: index,
///   child: Padding(
///     padding: EdgeInsets.all(14),
///     child: Column(children: [ ... ]),
///   ),
/// )
/// ```
///
/// Pass [tone] to pin a specific paper color (e.g. a user-chosen note
/// color), [tilted: false] for inline layouts, and [selected] for the
/// periwinkle selection ring.
class PaperSurface extends StatelessWidget {
  final Widget child;

  /// Selects the paper tone, tilt, and default doodle deterministically.
  final int seed;

  /// Explicit paper tone override; null cycles the token palette by [seed].
  final Color? tone;

  /// Apply the hand-placed tilt. Keep false for inline rows or wide sheets
  /// where rotation would fight the layout.
  final bool tilted;

  /// Draws the periwinkle selection ring instead of the borderless edge.
  final bool selected;

  /// Fixed border override (dark-mode hairlines, HC themes). Null resolves
  /// from brightness: none in light mode, muted tone border in dark.
  final Border? border;

  /// Corner radius; defaults to the sticky-note token (12).
  final BorderRadius? borderRadius;

  /// Show a hand-drawn doodle in the bottom-end corner of the sheet.
  final bool showDoodle;

  /// Fixed doodle kind; null cycles the sketch set by [seed].
  final PaperDoodleKind? doodleKind;

  const PaperSurface({
    super.key,
    required this.child,
    this.seed = 0,
    this.tone,
    this.tilted = true,
    this.selected = false,
    this.border,
    this.borderRadius,
    this.showDoodle = false,
    this.doodleKind,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = PaperTokens.of(context);
    final radius = borderRadius ?? BorderRadius.circular(paper.radius);

    final resolvedBorder = border ??
        (selected
            ? Border.all(
                color: Theme.of(context).colorScheme.primary, width: 1.5)
            : brightness == Brightness.dark
                ? Border.all(color: AppColors.darkBorder, width: 1)
                : null);

    Widget sheet = DecoratedBox(
      decoration: BoxDecoration(
        color: tone ?? paper.toneFor(seed, brightness),
        borderRadius: radius,
        border: resolvedBorder,
        boxShadow: AppShadows.paperOf(brightness),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: showDoodle
            ? Stack(
                children: [
                  Positioned.fill(child: child),
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    end: 12,
                    bottom: 10,
                    child: ExcludeSemantics(
                      child: PaperDoodle(
                        kind: doodleKind ??
                            PaperDoodleKindX.forSeed(seed),
                        color: paper.inkDoodle.withAlpha(150),
                      ),
                    ),
                  ),
                ],
              )
            : child,
      ),
    );

    if (tilted) {
      sheet = Transform.rotate(angle: paper.tiltFor(seed), child: sheet);
    }
    return sheet;
  }
}
