import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sticky-note paper design tokens — the skeuomorphic foundation extracted
/// from the 2026-05 mockup.
///
/// The aesthetic: content lives on pieces of paper resting on a desk. Each
/// sheet has a saturated candy-pastel tone, a small Post-it radius, no
/// border (the color block + a warm two-layer shadow define the edge), and
/// a slight hand-placed tilt. Dark mode keeps the color identity as a muted
/// wash over the navy surface.
///
/// Register as a [ThemeExtension] so any screen resolves the same paper
/// system through the theme:
///
/// ```dart
/// final paper = PaperTokens.of(context);
/// Container(
///   color: paper.toneFor(index, Theme.of(context).brightness),
///   ...
/// );
/// ```
///
/// Prefer the [PaperSurface] widget (core/widgets) which applies these
/// tokens for you; reach for the raw tokens when composing custom layouts.
@immutable
class PaperTokens extends ThemeExtension<PaperTokens> {
  /// Saturated paper tones, cycled per item (sampled from the mockup).
  final List<Color> papers;

  /// Surface behind the paper — slightly deeper than the app background so
  /// sheets pop (light mode only; dark mode uses the normal surface).
  final Color desk;

  /// Primary ink for text written on paper.
  final Color ink;

  /// Muted ink for timestamps and captions on paper.
  final Color inkMuted;

  /// Ink used by hand-drawn doodle strokes.
  final Color inkDoodle;

  /// Dark-mode base the paper tone washes over (alpha [darkWashAlpha]).
  final Color darkWashBase;
  final int darkWashAlpha;

  /// Per-item tilt cycle in radians (±~1.9°, deterministic hand-placed feel).
  final List<double> tilts;

  /// Sticky-note corner radius (a real Post-it, not a rounded card).
  final double radius;

  const PaperTokens({
    required this.papers,
    required this.desk,
    required this.ink,
    required this.inkMuted,
    required this.inkDoodle,
    required this.darkWashBase,
    required this.darkWashAlpha,
    required this.tilts,
    required this.radius,
  });

  /// Light mode: full-strength paper on the warm desk.
  static const PaperTokens light = PaperTokens(
    papers: AppColors.notePapers,
    desk: AppColors.lightDeskBg,
    ink: AppColors.lightTextPrimary,
    inkMuted: AppColors.lightTextTertiary,
    inkDoodle: AppColors.lightTextSecondary,
    darkWashBase: AppColors.darkCardBg,
    darkWashAlpha: 58,
    tilts: [-0.032, 0.024, -0.018, 0.03, -0.026, 0.021],
    radius: 12,
  );

  /// Dark mode: same color identity, muted washes over navy.
  static const PaperTokens dark = PaperTokens(
    papers: AppColors.notePapers,
    desk: AppColors.darkSurface,
    ink: AppColors.darkTextPrimary,
    inkMuted: AppColors.darkTextTertiary,
    inkDoodle: AppColors.darkTextTertiary,
    darkWashBase: AppColors.darkCardBg,
    darkWashAlpha: 58,
    tilts: [-0.032, 0.024, -0.018, 0.03, -0.026, 0.021],
    radius: 12,
  );

  /// Resolves from the current theme; falls back to the brightness default
  /// when the theme does not carry the extension (e.g. custom host themes).
  static PaperTokens of(BuildContext context) {
    final tokens =
        Theme.of(context).extension<PaperTokens>();
    if (tokens != null) return tokens;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  /// Resolved sheet color for item [index] under [brightness]: the saturated
  /// tone in light mode, a muted wash over the navy card base in dark mode.
  Color toneFor(int index, Brightness brightness) {
    final tone = papers[index % papers.length];
    if (brightness == Brightness.dark) {
      return Color.alphaBlend(tone.withAlpha(darkWashAlpha), darkWashBase);
    }
    return tone;
  }

  /// Deterministic tilt for item [index].
  double tiltFor(int index) => tilts[index % tilts.length];

  @override
  String toString() =>
      'PaperTokens(papers: ${papers.length} tones, desk: $desk, radius: $radius)';

  @override
  PaperTokens copyWith({
    List<Color>? papers,
    Color? desk,
    Color? ink,
    Color? inkMuted,
    Color? inkDoodle,
    Color? darkWashBase,
    int? darkWashAlpha,
    List<double>? tilts,
    double? radius,
  }) {
    return PaperTokens(
      papers: papers ?? this.papers,
      desk: desk ?? this.desk,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkDoodle: inkDoodle ?? this.inkDoodle,
      darkWashBase: darkWashBase ?? this.darkWashBase,
      darkWashAlpha: darkWashAlpha ?? this.darkWashAlpha,
      tilts: tilts ?? this.tilts,
      radius: radius ?? this.radius,
    );
  }

  @override
  PaperTokens lerp(ThemeExtension<PaperTokens>? other, double t) {
    if (other is! PaperTokens) return this;
    if (t == 0.0) return this;
    if (t == 1.0) return other;
    return PaperTokens(
      papers: List.generate(
        papers.length,
        (i) => Color.lerp(papers[i], other.papers[i % other.papers.length], t)!,
      ),
      desk: Color.lerp(desk, other.desk, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkDoodle: Color.lerp(inkDoodle, other.inkDoodle, t)!,
      darkWashBase: Color.lerp(darkWashBase, other.darkWashBase, t)!,
      darkWashAlpha: lerpInt(darkWashAlpha, other.darkWashAlpha, t),
      tilts: t < 0.5 ? tilts : other.tilts,
      radius: lerpDouble(radius, other.radius, t),
    );
  }

  static int lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
