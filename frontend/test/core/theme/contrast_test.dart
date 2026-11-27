import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/theme/app_colors.dart';
import 'package:anynote/core/theme/app_theme.dart';
import 'package:anynote/core/theme/paper_tokens.dart';

/// WCAG contrast, as an assertion rather than a comment.
///
/// `app_colors.dart` used to say every text tier met AA while the tertiary
/// tier was 2.97:1, "saved" was 2.39:1 and white on the accent 3.42:1; the
/// design review found it by measuring. These tests measure.
double _luminance(Color color) {
  final argb = color.toARGB32();
  double channel(int value) {
    final c = (value & 0xFF) / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(argb >> 16) +
      0.7152 * channel(argb >> 8) +
      0.0722 * channel(argb);
}

/// WCAG contrast ratio of [a] on [b].
double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// WCAG AA for text: 4.5:1; for icons and other graphics: 3:1.
const aa = 4.5;
const graphics = 3.0;

void readsOn(Color ink, List<Color> surfaces, {double atLeast = aa}) {
  for (final surface in surfaces) {
    expect(
      contrast(ink, surface),
      greaterThanOrEqualTo(atLeast),
      reason:
          '$ink on $surface is ${contrast(ink, surface).toStringAsFixed(2)}:1',
    );
  }
}

void main() {
  const lightSurfaces = [
    AppColors.lightSurface,
    AppColors.lightCardBg,
    AppColors.lightInputFill,
    // The desk behind the notes and under the app bars: a labelled action
    // in a bar is written on it.
    AppColors.lightDeskBg,
  ];
  const darkSurfaces = [
    AppColors.darkSurface,
    AppColors.darkCardBg,
    AppColors.darkInputFill,
  ];

  group('light theme', () {
    test('every text tier reads on every surface', () {
      readsOn(AppColors.lightTextPrimary, lightSurfaces);
      readsOn(AppColors.lightTextSecondary, lightSurfaces);
      readsOn(AppColors.lightTextTertiary, lightSurfaces);
    });

    test('the accent carries white, and reads as text itself', () {
      readsOn(Colors.white, [AppColors.primary, AppColors.primaryDark]);
      readsOn(AppColors.primary, lightSurfaces);
      readsOn(AppColors.primaryText, lightSurfaces);
      // One purple: the accent as a fill and the accent as text are a value.
      expect(AppColors.primaryText, AppColors.primary);
    });

    test('status ink reads; the status fills are not asked to', () {
      readsOn(AppColors.statusSuccessInk, lightSurfaces);
      readsOn(AppColors.statusWarningInk, lightSurfaces);
      readsOn(AppColors.statusErrorInk, lightSurfaces);
    });
  });

  group('dark theme', () {
    test('every text tier reads on every surface', () {
      readsOn(AppColors.darkTextPrimary, darkSurfaces);
      readsOn(AppColors.darkTextSecondary, darkSurfaces);
      readsOn(AppColors.darkTextTertiary, darkSurfaces);
    });

    test('the accent carries its label', () {
      final scheme = AppTheme.darkTheme().colorScheme;
      readsOn(scheme.onPrimary, [scheme.primary]);
      readsOn(scheme.primary, darkSurfaces);
    });

    test('status ink reads', () {
      readsOn(AppColors.statusSuccessInkDark, darkSurfaces);
      readsOn(AppColors.statusWarningInkDark, darkSurfaces);
      readsOn(AppColors.statusErrorInkDark, darkSurfaces);
    });
  });

  group('on the sticky notes', () {
    const papers = AppColors.notePapers;

    test('light: the time, the preview and the title read on every sheet', () {
      for (var i = 0; i < papers.length; i++) {
        readsOn(AppColors.paperInks[i], [papers[i]]);
        readsOn(AppColors.lightTextSecondary, [papers[i]]);
        readsOn(AppColors.lightTextPrimary, [papers[i]]);
        // The pin is an icon: 3:1 is the bar.
        readsOn(AppColors.primary, [papers[i]], atLeast: graphics);
      }
    });

    test('light: each sheet looks its ink up', () {
      for (var i = 0; i < papers.length; i++) {
        expect(PaperTokens.light.inkOn(papers[i]), AppColors.paperInks[i]);
      }
      // A tone that is not one of the papers gets the fallback.
      expect(
        PaperTokens.light.inkOn(AppColors.lightCardBg),
        PaperTokens.light.inkMuted,
      );
    });

    test('dark: the time, the preview and the title read on every wash', () {
      for (var i = 0; i < papers.length; i++) {
        final wash = PaperTokens.dark.toneFor(i, Brightness.dark);
        readsOn(PaperTokens.dark.inkMuted, [wash]);
        readsOn(PaperTokens.dark.inkOn(wash), [wash]);
        readsOn(AppColors.darkTextSecondary, [wash]);
        readsOn(AppColors.darkTextPrimary, [wash]);
        // The pin takes the dark theme's accent, an icon: 3:1 is the bar.
        // In the light theme's purple it was 1.45–1.60:1 on every wash.
        readsOn(AppColors.secondary, [wash], atLeast: graphics);
      }
    });

    test("dark: every sheet takes the theme's ink, however its tone arrives",
        () {
      for (var i = 0; i < papers.length; i++) {
        final wash = PaperTokens.dark.toneFor(i, Brightness.dark);
        // Painted as a wash, or named by the paper it was made from: the
        // light theme's darkened inks must not reach a dark sheet either way.
        expect(PaperTokens.dark.inkOn(wash), AppColors.darkTextSecondary);
        expect(PaperTokens.dark.inkOn(papers[i]), AppColors.darkTextSecondary);
        readsOn(PaperTokens.dark.inkOn(papers[i]), [wash]);
      }
    });

    test('each theme names an ink for every sheet', () {
      for (final tokens in [PaperTokens.light, PaperTokens.dark]) {
        expect(tokens.paperInks.length, tokens.papers.length);
      }
    });
  });

  group('the theme hands these colours out', () {
    test('light', () {
      final theme = AppTheme.lightTheme();
      final filled = theme.filledButtonTheme.style;
      final fab = theme.floatingActionButtonTheme;
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(filled?.backgroundColor?.resolve({}), AppColors.primary);
      expect(fab.backgroundColor, AppColors.primary);
    });

    test('dark', () {
      final theme = AppTheme.darkTheme();
      final filled = theme.filledButtonTheme.style;
      expect(
        filled?.backgroundColor?.resolve({}),
        theme.colorScheme.primary,
      );
      expect(
        filled?.foregroundColor?.resolve({}),
        theme.colorScheme.onPrimary,
      );
    });
  });
}
