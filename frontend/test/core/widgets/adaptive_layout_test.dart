import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/constants/breakpoints.dart';
import 'package:anynote/core/widgets/adaptive_builder.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Breakpoints
  // ---------------------------------------------------------------------------

  group('Breakpoints', () {
    test('isCompact returns true for widths below 600', () {
      expect(Breakpoints.isCompact(0), isTrue);
      expect(Breakpoints.isCompact(299), isTrue);
      expect(Breakpoints.isCompact(599), isTrue);
      expect(Breakpoints.isCompact(599.9), isTrue);
    });

    test('isCompact returns false for widths >= 600', () {
      expect(Breakpoints.isCompact(600), isFalse);
      expect(Breakpoints.isCompact(800), isFalse);
      expect(Breakpoints.isCompact(1200), isFalse);
    });

    test('isMedium returns true for 600 <= width < 1024', () {
      expect(Breakpoints.isMedium(600), isTrue);
      expect(Breakpoints.isMedium(800), isTrue);
      expect(Breakpoints.isMedium(1023), isTrue);
      expect(Breakpoints.isMedium(1023.9), isTrue);
    });

    test('isMedium returns false outside 600-1023 range', () {
      expect(Breakpoints.isMedium(599), isFalse);
      expect(Breakpoints.isMedium(1024), isFalse);
      expect(Breakpoints.isMedium(0), isFalse);
    });

    test('isExpanded returns true for width >= 1024', () {
      expect(Breakpoints.isExpanded(1024), isTrue);
      expect(Breakpoints.isExpanded(1200), isTrue);
      expect(Breakpoints.isExpanded(1920), isTrue);
    });

    test('isExpanded returns false for width < 1024', () {
      expect(Breakpoints.isExpanded(1023), isFalse);
      expect(Breakpoints.isExpanded(800), isFalse);
      expect(Breakpoints.isExpanded(0), isFalse);
    });

    test('isSideBySide returns true for width >= 600', () {
      expect(Breakpoints.isSideBySide(600), isTrue);
      expect(Breakpoints.isSideBySide(1024), isTrue);
      expect(Breakpoints.isSideBySide(599), isFalse);
    });

    test('exactly one breakpoint category is true for any width', () {
      final widths = <double>[0.0, 100, 599, 600, 800, 1023, 1024, 1200, 1920];
      for (final w in widths) {
        final count = [
          Breakpoints.isCompact(w),
          Breakpoints.isMedium(w),
          Breakpoints.isExpanded(w),
        ].where((v) => v).length;
        expect(count, 1, reason: 'Expected exactly one category for width $w');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // AdaptiveBuilder
  // ---------------------------------------------------------------------------

  group('AdaptiveBuilder', () {
    Future<void> pumpAtSize(
      WidgetTester tester, {
      required double width,
      required double height,
      required WidgetBuilder compactBuilder,
      WidgetBuilder? mediumBuilder,
      WidgetBuilder? expandedBuilder,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveBuilder(
            compactBuilder: compactBuilder,
            mediumBuilder: mediumBuilder,
            expandedBuilder: expandedBuilder,
          ),
        ),
      );
    }

    testWidgets('shows compact builder at phone width', (tester) async {
      await pumpAtSize(
        tester,
        width: 400,
        height: 800,
        compactBuilder: (_) => const Text('compact'),
        mediumBuilder: (_) => const Text('medium'),
        expandedBuilder: (_) => const Text('expanded'),
      );
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('shows medium builder at tablet width', (tester) async {
      await pumpAtSize(
        tester,
        width: 800,
        height: 600,
        compactBuilder: (_) => const Text('compact'),
        mediumBuilder: (_) => const Text('medium'),
        expandedBuilder: (_) => const Text('expanded'),
      );
      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('shows expanded builder at desktop width', (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        compactBuilder: (_) => const Text('compact'),
        mediumBuilder: (_) => const Text('medium'),
        expandedBuilder: (_) => const Text('expanded'),
      );
      expect(find.text('expanded'), findsOneWidget);
    });

    testWidgets('falls back to compact when medium is null', (tester) async {
      await pumpAtSize(
        tester,
        width: 800,
        height: 600,
        compactBuilder: (_) => const Text('compact'),
        expandedBuilder: (_) => const Text('expanded'),
      );
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('falls back to medium when expanded is null', (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        compactBuilder: (_) => const Text('compact'),
        mediumBuilder: (_) => const Text('medium'),
      );
      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('falls back to compact when both medium and expanded are null',
        (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        compactBuilder: (_) => const Text('compact'),
      );
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('at boundary 600 shows medium builder', (tester) async {
      await pumpAtSize(
        tester,
        width: 600,
        height: 800,
        compactBuilder: (_) => const Text('compact'),
        mediumBuilder: (_) => const Text('medium'),
      );
      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('at boundary 1024 shows expanded builder', (tester) async {
      await pumpAtSize(
        tester,
        width: 1024,
        height: 800,
        compactBuilder: (_) => const Text('compact'),
        mediumBuilder: (_) => const Text('medium'),
        expandedBuilder: (_) => const Text('expanded'),
      );
      expect(find.text('expanded'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // AdaptiveVisibility
  // ---------------------------------------------------------------------------

  group('AdaptiveVisibility', () {
    Future<void> pumpAtSize(
      WidgetTester tester, {
      required double width,
      required double height,
      required bool Function(double) visibleWhen,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveVisibility(
            visibleWhen: visibleWhen,
            child: const Text('visible-child'),
          ),
        ),
      );
    }

    testWidgets('child is visible when predicate returns true', (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        visibleWhen: (w) => Breakpoints.isExpanded(w),
      );
      expect(find.text('visible-child'), findsOneWidget);
    });

    testWidgets('child is invisible when predicate returns false',
        (tester) async {
      await pumpAtSize(
        tester,
        width: 400,
        height: 800,
        visibleWhen: (w) => Breakpoints.isExpanded(w),
      );
      // Visibility with maintainState: false removes the child from the tree.
      expect(find.text('visible-child'), findsNothing);
      // The Visibility widget should still be present.
      final visibility = tester.widget<Visibility>(find.byType(Visibility));
      expect(visibility.visible, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // AdaptivePadding
  // ---------------------------------------------------------------------------

  group('AdaptivePadding', () {
    Future<void> pumpAtSize(
      WidgetTester tester, {
      required double width,
      required double height,
      double maxContentWidth = 840,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptivePadding(
            maxContentWidth: maxContentWidth,
            child: const SizedBox(width: 200, height: 50),
          ),
        ),
      );
    }

    testWidgets('wraps in ConstrainedBox on expanded width', (tester) async {
      await pumpAtSize(tester, width: 1200, height: 800);
      // Center and ConstrainedBox are both present.
      expect(find.byType(ConstrainedBox), findsWidgets);
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('uses horizontal padding on medium width', (tester) async {
      await pumpAtSize(tester, width: 800, height: 600);
      // Should find Padding but not ConstrainedBox at the top level.
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('uses minimal padding on compact width', (tester) async {
      await pumpAtSize(tester, width: 400, height: 800);
      expect(find.byType(Padding), findsWidgets);
    });

    testWidgets('respects custom maxContentWidth', (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        maxContentWidth: 500,
      );
      // Find the ConstrainedBox that is a direct child of Center (our widget).
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.byType(ConstrainedBox),
      );
      // At least one should have maxWidth == 500.
      final hasMaxWidth500 = constrainedBoxes.any(
        (cb) => cb.constraints.maxWidth == 500,
      );
      expect(hasMaxWidth500, isTrue);
    });
  });
}
