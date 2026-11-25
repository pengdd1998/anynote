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
/// The sheet's writing is two voices: the title is handwritten in [ink]; the
/// preview and the time are the interface's own face, in inks that each read
/// at WCAG AA on that sheet (the theme's secondary text colour for the
/// preview, [inkOn] for the time).
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

  /// Muted ink for timestamps and captions on a sheet that is not one of
  /// [papers] (a note's own colour, a selection tint, the plain card).
  final Color inkMuted;

  /// Muted ink for each of [papers], in the same order: the sheet's own hue,
  /// darkened until it reads. Resolve a sheet's ink with [inkOn]. In [dark]
  /// every entry is the theme's secondary ink — its sheets are washes.
  final List<Color> paperInks;

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
    required this.paperInks,
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
    inkMuted: AppColors.lightTextSecondary,
    paperInks: AppColors.paperInks,
    inkDoodle: AppColors.lightTextSecondary,
    darkWashBase: AppColors.darkCardBg,
    darkWashAlpha: 58,
    tilts: [-0.032, 0.024, -0.018, 0.03, -0.026, 0.021],
    radius: 12,
  );

  /// Dark mode: same color identity, muted washes over navy.
  ///
  /// A dark sheet is a wash, and the washes lie within a few steps of one
  /// another, so there is no ink to mix per sheet: the time takes the theme's
  /// secondary ink on every one of them, as the preview already does.
  static const PaperTokens dark = PaperTokens(
    papers: AppColors.notePapers,
    desk: AppColors.darkSurface,
    ink: AppColors.darkTextPrimary,
    inkMuted: AppColors.darkTextSecondary,
    paperInks: _inkForEveryDarkSheet,
    inkDoodle: AppColors.darkTextTertiary,
    darkWashBase: AppColors.darkCardBg,
    darkWashAlpha: 58,
    tilts: [-0.032, 0.024, -0.018, 0.03, -0.026, 0.021],
    radius: 12,
  );

  /// One entry per paper, all the secondary ink, so that [inkOn] gives a dark
  /// sheet the same ink however its tone arrives — as the wash it is painted
  /// as, or as the paper tone it was made from.
  static const _inkForEveryDarkSheet = <Color>[
    AppColors.darkTextSecondary,
    AppColors.darkTextSecondary,
    AppColors.darkTextSecondary,
    AppColors.darkTextSecondary,
    AppColors.darkTextSecondary,
    AppColors.darkTextSecondary,
  ];

  /// Resolves from the current theme; falls back to the brightness default
  /// when the theme does not carry the extension (e.g. custom host themes).
  static PaperTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<PaperTokens>();
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

  /// Muted ink that reads on the sheet [tone] paints: its own from
  /// [paperInks] when it is one of the papers, otherwise [inkMuted].
  Color inkOn(Color tone) {
    final index = papers.indexOf(tone);
    if (index < 0 || index >= paperInks.length) return inkMuted;
    return paperInks[index];
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
    List<Color>? paperInks,
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
      paperInks: paperInks ?? this.paperInks,
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
      paperInks: List.generate(
        paperInks.length,
        (i) => Color.lerp(
            paperInks[i], other.paperInks[i % other.paperInks.length], t)!,
      ),
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
