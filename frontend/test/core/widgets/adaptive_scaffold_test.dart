import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/adaptive_scaffold.dart';

void main() {
  group('AdaptiveScaffold', () {
    // -- Helper to pump at a specific screen size ----------------------------

    Future<void> pumpAtSize(
      WidgetTester tester, {
      required double width,
      required double height,
      required Widget phoneLayout,
      Widget? tabletLayout,
      Widget? desktopLayout,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            phoneLayout: phoneLayout,
            tabletLayout: tabletLayout,
            desktopLayout: desktopLayout,
          ),
        ),
      );
    }

    // -- Static helpers -------------------------------------------------------

    testWidgets('isPhone returns true for width < 600', (tester) async {
      await pumpAtSize(
        tester,
        width: 400,
        height: 800,
        phoneLayout: const _Label('phone'),
      );

      // Access static method via a build context.
      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isPhone(context), isTrue);
      expect(AdaptiveScaffold.isTablet(context), isFalse);
      expect(AdaptiveScaffold.isDesktop(context), isFalse);
    });

    testWidgets('isTablet returns true for width 600-1023', (tester) async {
      await pumpAtSize(
        tester,
        width: 800,
        height: 600,
        phoneLayout: const _Label('phone'),
      );

      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isPhone(context), isFalse);
      expect(AdaptiveScaffold.isTablet(context), isTrue);
      expect(AdaptiveScaffold.isDesktop(context), isFalse);
    });

    testWidgets('isDesktop returns true for width >= 1024', (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        phoneLayout: const _Label('phone'),
      );

      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isPhone(context), isFalse);
      expect(AdaptiveScaffold.isTablet(context), isFalse);
      expect(AdaptiveScaffold.isDesktop(context), isTrue);
    });

    testWidgets('boundary: width exactly 599 is phone', (tester) async {
      await pumpAtSize(
        tester,
        width: 599,
        height: 800,
        phoneLayout: const _Label('phone'),
      );

      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isPhone(context), isTrue);
    });

    testWidgets('boundary: width exactly 600 is tablet', (tester) async {
      await pumpAtSize(
        tester,
        width: 600,
        height: 800,
        phoneLayout: const _Label('phone'),
      );

      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isTablet(context), isTrue);
    });

    testWidgets('boundary: width exactly 1023 is tablet', (tester) async {
      await pumpAtSize(
        tester,
        width: 1023,
        height: 800,
        phoneLayout: const _Label('phone'),
      );

      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isTablet(context), isTrue);
    });

    testWidgets('boundary: width exactly 1024 is desktop', (tester) async {
      await pumpAtSize(
        tester,
        width: 1024,
        height: 800,
        phoneLayout: const _Label('phone'),
      );

      final context = tester.element(find.byType(AdaptiveScaffold));
      expect(AdaptiveScaffold.isDesktop(context), isTrue);
    });

    // -- Layout selection -----------------------------------------------------

    testWidgets('shows phone layout at phone width', (tester) async {
      await pumpAtSize(
        tester,
        width: 400,
        height: 800,
        phoneLayout: const _Label('phone'),
        tabletLayout: const _Label('tablet'),
        desktopLayout: const _Label('desktop'),
      );

      expect(find.text('phone'), findsOneWidget);
      expect(find.text('tablet'), findsNothing);
      expect(find.text('desktop'), findsNothing);
    });

    testWidgets('shows tablet layout at tablet width', (tester) async {
      await pumpAtSize(
        tester,
        width: 800,
        height: 600,
        phoneLayout: const _Label('phone'),
        tabletLayout: const _Label('tablet'),
        desktopLayout: const _Label('desktop'),
      );

      expect(find.text('phone'), findsNothing);
      expect(find.text('tablet'), findsOneWidget);
      expect(find.text('desktop'), findsNothing);
    });

    testWidgets('shows desktop layout at desktop width', (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        phoneLayout: const _Label('phone'),
        tabletLayout: const _Label('tablet'),
        desktopLayout: const _Label('desktop'),
      );

      expect(find.text('phone'), findsNothing);
      expect(find.text('tablet'), findsNothing);
      expect(find.text('desktop'), findsOneWidget);
    });

    // -- Fallback behavior ---------------------------------------------------

    testWidgets('falls back to phone when tablet layout is null at tablet width',
        (tester) async {
      await pumpAtSize(
        tester,
        width: 800,
        height: 600,
        phoneLayout: const _Label('phone'),
        // tabletLayout intentionally omitted
        desktopLayout: const _Label('desktop'),
      );

      expect(find.text('phone'), findsOneWidget);
      expect(find.text('desktop'), findsNothing);
    });

    testWidgets(
        'falls back to tablet when desktop layout is null at desktop width',
        (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        phoneLayout: const _Label('phone'),
        tabletLayout: const _Label('tablet'),
        // desktopLayout intentionally omitted
      );

      expect(find.text('tablet'), findsOneWidget);
      expect(find.text('phone'), findsNothing);
    });

    testWidgets(
        'falls back to phone when both tablet and desktop are null at desktop width',
        (tester) async {
      await pumpAtSize(
        tester,
        width: 1200,
        height: 800,
        phoneLayout: const _Label('phone'),
        // tabletLayout and desktopLayout intentionally omitted
      );

      expect(find.text('phone'), findsOneWidget);
    });

    testWidgets('falls back to phone when both tablet and desktop are null at tablet width',
        (tester) async {
      await pumpAtSize(
        tester,
        width: 700,
        height: 800,
        phoneLayout: const _Label('phone'),
        // tabletLayout and desktopLayout intentionally omitted
      );

      expect(find.text('phone'), findsOneWidget);
    });

    // -- Phone layout only (minimal configuration) --------------------------

    testWidgets('renders with only phone layout at phone width', (tester) async {
      await pumpAtSize(
        tester,
        width: 400,
        height: 800,
        phoneLayout: const _Label('phone-only'),
      );

      expect(find.text('phone-only'), findsOneWidget);
    });
  });
}

/// Simple labeled widget for identifying which layout is rendered.
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text);
}
