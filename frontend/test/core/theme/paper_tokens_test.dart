import 'package:anynote/core/theme/app_theme.dart';
import 'package:anynote/core/theme/paper_tokens.dart';
import 'package:anynote/core/widgets/paper_doodle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the sticky-note paper design system — the tokens and surfaces
/// extracted from the 2026-05 mockup so any screen can render content
/// "on paper" consistently.
void main() {
  group('PaperTokens', () {
    test('light mode resolves full-strength paper tones', () {
      final tone = PaperTokens.light.toneFor(0, Brightness.light);
      expect(tone, PaperTokens.light.papers[0]);
      expect(tone, AppPaperExpectations.saturatedYellow);
    });

    test('dark mode resolves a muted wash over the navy card base', () {
      final tone = PaperTokens.dark.toneFor(0, Brightness.dark);
      expect(tone, isNot(PaperTokens.dark.papers[0]));
      // The wash must land between the raw tone and the dark base.
      expect(tone, AppPaperExpectations.mutedWash);
    });

    test('tone and tilt cycles are deterministic per index', () {
      for (var i = 0; i < 12; i++) {
        expect(
          PaperTokens.light.toneFor(i, Brightness.light),
          PaperTokens.light.toneFor(i, Brightness.light),
        );
        expect(
          PaperTokens.light.tiltFor(i),
          PaperTokens.light.tiltFor(i),
        );
      }
      // Cycle wraps.
      expect(
        PaperTokens.light.tiltFor(0),
        PaperTokens.light.tiltFor(PaperTokens.light.tilts.length),
      );
    });

    test('tilts are small enough to read as hand-placed, not crooked', () {
      for (final t in PaperTokens.light.tilts) {
        expect(t.abs(), lessThan(0.05)); // < ~2.9°
        expect(t, isNot(0));
      }
    });

    test('lerp blends colors and swaps structural lists midway', () {
      final blended = PaperTokens.light.lerp(PaperTokens.dark, 0.5);
      expect(blended.desk, isNot(PaperTokens.light.desk));
      expect(blended.desk, isNot(PaperTokens.dark.desk));
      expect(blended.darkWashAlpha, 58); // both sides are 58
      expect(blended.radius, closeTo(PaperTokens.light.radius, 0.01));
    });
  });

  group('PaperDoodleKindX.forSeed', () {
    test('is deterministic and cycles the sketch set', () {
      expect(
        PaperDoodleKindX.forSeed(42),
        PaperDoodleKindX.forSeed(42),
      );
      expect(
        PaperDoodleKindX.forSeed(0),
        PaperDoodleKindX.forSeed(PaperDoodleKindX.cycleLength),
      );
    });
  });

  group('theme registration', () {
    testWidgets('light and dark themes carry the paper tokens', (tester) async {
      late PaperTokens fromLight;
      late PaperTokens fromDark;
      // Inject via Theme directly — MaterialApp animates theme switches,
      // which would catch the tokens mid-interpolation.
      await tester.pumpWidget(
        Theme(
          data: AppTheme.light,
          child: Builder(
            builder: (context) {
              fromLight = PaperTokens.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        Theme(
          data: AppTheme.dark,
          child: Builder(
            builder: (context) {
              fromDark = PaperTokens.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(fromLight.desk, PaperTokens.light.desk);
      expect(fromDark.desk, PaperTokens.dark.desk);
      // Desk sits deeper than the app background so sheets pop.
      expect(fromLight.desk, isNot(AppTheme.light.scaffoldBackgroundColor));
      expect(fromDark.ink, isNot(fromLight.ink));
    });
  });
}

/// Expected values kept here instead of hardcoding hex constants inline.
class AppPaperExpectations {
  /// paperYellow — the saturated light-mode tone.
  static final Color saturatedYellow = PaperTokens.light.papers[0];

  /// The dark-mode wash: yellow at 58/255 alpha over the navy card base.
  static final Color mutedWash = Color.alphaBlend(
    PaperTokens.dark.papers[0].withAlpha(58),
    PaperTokens.dark.darkWashBase,
  );
}
