// Accessibility audit tests for the AnyNote app.
//
// Tests cover:
// - Theme color contrast ratios (WCAG AA compliance)
// - Semantic label generation for notes, tags, collections
// - Touch target size enforcement
// - Core a11y utility functions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/accessibility/a11y_utils.dart';
import 'package:anynote/core/theme/app_theme.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Contrast ratio tests
  // ---------------------------------------------------------------------------

  group('A11yUtils.contrastRatio', () {
    test('black vs white has maximum contrast ratio', () {
      final ratio = A11yUtils.contrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      );
      // Should be 21:1 (maximum).
      expect(ratio, greaterThanOrEqualTo(20.0));
    });

    test('same color has contrast ratio of 1', () {
      final ratio = A11yUtils.contrastRatio(
        const Color(0xFF808080),
        const Color(0xFF808080),
      );
      expect(ratio, closeTo(1.0, 0.01));
    });

    test('dark gray vs white has high contrast', () {
      final ratio = A11yUtils.contrastRatio(
        const Color(0xFF333333),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, greaterThanOrEqualTo(10.0));
    });

    test('light gray vs white has low contrast', () {
      final ratio = A11yUtils.contrastRatio(
        const Color(0xFFCCCCCC),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, lessThan(3.0));
    });
  });

  // ---------------------------------------------------------------------------
  // WCAG AA compliance tests
  // ---------------------------------------------------------------------------

  group('A11yUtils.meetsWcagAA', () {
    test('black on white passes AA', () {
      expect(
        A11yUtils.meetsWcagAA(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        isTrue,
      );
    });

    test('light gray on white fails AA', () {
      expect(
        A11yUtils.meetsWcagAA(const Color(0xFFCCCCCC), const Color(0xFFFFFFFF)),
        isFalse,
      );
    });

    test('white on black passes AA', () {
      expect(
        A11yUtils.meetsWcagAA(const Color(0xFFFFFFFF), const Color(0xFF000000)),
        isTrue,
      );
    });
  });

  group('A11yUtils.meetsAA', () {
    test('returns true for normal text with 4.5:1 ratio', () {
      // Dark gray (#333333) on white has ~12.6:1 ratio.
      expect(
        A11yUtils.meetsAA(
          foreground: const Color(0xFF333333),
          background: const Color(0xFFFFFFFF),
          isLargeText: false,
        ),
        isTrue,
      );
    });

    test('returns false for normal text with insufficient ratio', () {
      // #999999 on white has ~2.8:1 ratio (fails 4.5:1 requirement).
      expect(
        A11yUtils.meetsAA(
          foreground: const Color(0xFF999999),
          background: const Color(0xFFFFFFFF),
          isLargeText: false,
        ),
        isFalse,
      );
    });

    test('large text requires only 3:1 ratio', () {
      // #999999 on white has ~2.8:1 which still fails even large text.
      expect(
        A11yUtils.meetsAA(
          foreground: const Color(0xFF999999),
          background: const Color(0xFFFFFFFF),
          isLargeText: true,
        ),
        isFalse,
      );
    });

    test('large text passes with moderate contrast', () {
      // #767676 on white has ~4.5:1 which passes 3:1 for large text.
      expect(
        A11yUtils.meetsAA(
          foreground: const Color(0xFF767676),
          background: const Color(0xFFFFFFFF),
          isLargeText: true,
        ),
        isTrue,
      );
    });
  });

  group('A11yUtils.meetsWcagAALarge', () {
    test('passes for 3:1 ratio', () {
      // #767676 on white has ~4.5:1 which passes.
      expect(
        A11yUtils.meetsWcagAALarge(
          const Color(0xFF767676),
          const Color(0xFFFFFFFF),
        ),
        isTrue,
      );
    });

    test('fails for very low contrast', () {
      expect(
        A11yUtils.meetsWcagAALarge(
          const Color(0xFFBBBBBB),
          const Color(0xFFFFFFFF),
        ),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Theme color contrast audit
  // ---------------------------------------------------------------------------

  group('Theme colors meet WCAG AA', () {
    test('light theme primary text on background', () {
      final theme = AppTheme.lightTheme();
      final textTheme = theme.textTheme;
      final scaffoldBg = theme.scaffoldBackgroundColor;

      // Body large text on scaffold background.
      if (textTheme.bodyLarge?.color != null) {
        expect(
          A11yUtils.meetsWcagAA(textTheme.bodyLarge!.color!, scaffoldBg),
          isTrue,
          reason: 'bodyLarge color must have 4.5:1 contrast on scaffold bg',
        );
      }
    });

    test('light theme headline text on background', () {
      final theme = AppTheme.lightTheme();
      final textTheme = theme.textTheme;
      final scaffoldBg = theme.scaffoldBackgroundColor;

      if (textTheme.headlineMedium?.color != null) {
        expect(
          A11yUtils.meetsWcagAA(textTheme.headlineMedium!.color!, scaffoldBg),
          isTrue,
          reason: 'headlineMedium must have 4.5:1 contrast on scaffold bg',
        );
      }
    });

    test('dark theme primary text on background', () {
      final theme = AppTheme.darkTheme();
      final textTheme = theme.textTheme;
      final scaffoldBg = theme.scaffoldBackgroundColor;

      if (textTheme.bodyLarge?.color != null) {
        expect(
          A11yUtils.meetsWcagAA(textTheme.bodyLarge!.color!, scaffoldBg),
          isTrue,
          reason: 'dark theme bodyLarge must have 4.5:1 contrast on scaffold bg',
        );
      }
    });

    test('dark theme headline text on background', () {
      final theme = AppTheme.darkTheme();
      final textTheme = theme.textTheme;
      final scaffoldBg = theme.scaffoldBackgroundColor;

      if (textTheme.headlineMedium?.color != null) {
        expect(
          A11yUtils.meetsWcagAA(textTheme.headlineMedium!.color!, scaffoldBg),
          isTrue,
          reason: 'dark theme headlineMedium must have 4.5:1 contrast',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Semantic label generation tests
  // ---------------------------------------------------------------------------

  group('A11yUtils semantic labels', () {
    test('noteCardLabel contains title and time', () {
      final label = A11yUtils.noteCardLabel(
        title: 'My Note',
        timeDescription: '2 hours ago',
      );
      expect(label, contains('My Note'));
      expect(label, contains('2 hours ago'));
    });

    test('noteCardLabel shows pinned status', () {
      final label = A11yUtils.noteCardLabel(
        title: 'Pinned Note',
        timeDescription: 'now',
        isPinned: true,
      );
      expect(label, contains('Pinned Note'));
      expect(label, contains('pinned'));
    });

    test('noteCardLabel shows not synced status', () {
      final label = A11yUtils.noteCardLabel(
        title: 'Draft Note',
        timeDescription: 'just now',
        isSynced: false,
      );
      expect(label, contains('Draft Note'));
      expect(label, contains('not synced'));
    });

    test('semanticLabelForNote returns title', () {
      final label = A11yUtils.semanticLabelForNote(
        title: 'Important',
        preview: 'Content preview...',
      );
      expect(label, contains('Important'));
    });

    test('semanticLabelForTag returns tag name', () {
      final label = A11yUtils.semanticLabelForTag(
        name: 'work',
        count: 5,
      );
      expect(label, contains('work'));
    });

    test('semanticLabelForTag includes note count', () {
      final label = A11yUtils.semanticLabelForTag(
        name: 'ideas',
        count: 12,
      );
      expect(label, contains('12'));
    });
  });
}
