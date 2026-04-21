import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/cached_image.dart';

void main() {
  group('CachedImage', () {
    Future<void> pumpCachedImage(
      WidgetTester tester, {
      required String url,
      double? width,
      double? height,
      BoxFit fit = BoxFit.cover,
      BorderRadius? borderRadius,
      String? semanticLabel,
      Widget? loadingWidget,
      Widget? errorWidget,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CachedImage(
              url: url,
              width: width,
              height: height,
              fit: fit,
              borderRadius: borderRadius,
              semanticLabel: semanticLabel,
              loadingWidget: loadingWidget,
              errorWidget: errorWidget,
            ),
          ),
        ),
      );
    }

    // -- Construction and defaults -----------------------------------------

    testWidgets('renders without throwing for a valid URL', (tester) async {
      await pumpCachedImage(tester, url: 'https://example.com/photo.jpg');

      // CachedNetworkImage is present in the widget tree.
      expect(find.byType(CachedImage), findsOneWidget);
    });

    testWidgets('passes width and height to image widget', (tester) async {
      await pumpCachedImage(
        tester,
        url: 'https://example.com/photo.jpg',
        width: 200,
        height: 150,
      );

      final cachedImage = tester.widget<CachedImage>(find.byType(CachedImage));
      expect(cachedImage.width, 200);
      expect(cachedImage.height, 150);
    });

    testWidgets('defaults to BoxFit.cover', (tester) async {
      await pumpCachedImage(tester, url: 'https://example.com/photo.jpg');

      final cachedImage = tester.widget<CachedImage>(find.byType(CachedImage));
      expect(cachedImage.fit, BoxFit.cover);
    });

    testWidgets('respects custom BoxFit', (tester) async {
      await pumpCachedImage(
        tester,
        url: 'https://example.com/photo.jpg',
        fit: BoxFit.contain,
      );

      final cachedImage = tester.widget<CachedImage>(find.byType(CachedImage));
      expect(cachedImage.fit, BoxFit.contain);
    });

    testWidgets('default cacheDuration is 7 days', (tester) async {
      await pumpCachedImage(tester, url: 'https://example.com/photo.jpg');

      final cachedImage = tester.widget<CachedImage>(find.byType(CachedImage));
      expect(cachedImage.cacheDuration, const Duration(days: 7));
    });

    // -- Custom loading widget --------------------------------------------

    testWidgets('renders custom loading widget when provided',
        (tester) async {
      await pumpCachedImage(
        tester,
        url: 'https://example.com/photo.jpg',
        loadingWidget: const Text('Loading...'),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    // -- Custom error widget -----------------------------------------------

    testWidgets('renders custom error widget when provided',
        (tester) async {
      await pumpCachedImage(
        tester,
        url: 'https://example.com/photo.jpg',
        errorWidget: const Text('Image failed'),
      );

      expect(find.text('Image failed'), findsOneWidget);
    });

    // -- Border radius clipping -------------------------------------------

    testWidgets('wraps with ClipRRect when borderRadius is provided',
        (tester) async {
      await pumpCachedImage(
        tester,
        url: 'https://example.com/photo.jpg',
        borderRadius: BorderRadius.circular(12),
      );

      expect(find.byType(ClipRRect), findsOneWidget);

      final clipRRect =
          tester.widget<ClipRRect>(find.byType(ClipRRect));
      final borderRadius =
          clipRRect.borderRadius as BorderRadius?;
      expect(borderRadius, isNotNull);
    });

    testWidgets('does not wrap with ClipRRect when borderRadius is null',
        (tester) async {
      await pumpCachedImage(tester, url: 'https://example.com/photo.jpg');

      expect(find.byType(ClipRRect), findsNothing);
    });

    // -- Semantics ---------------------------------------------------------

    testWidgets('wraps with Semantics when no borderRadius', (tester) async {
      await pumpCachedImage(
        tester,
        url: 'https://example.com/photo.jpg',
        semanticLabel: 'A photo of a cat',
      );

      // When no borderRadius, the widget uses Semantics wrapper.
      expect(find.byType(Semantics), findsOneWidget);

      final semantics = tester.widget<Semantics>(find.byType(Semantics));
      expect(semantics.properties.label, 'A photo of a cat');
    });

    // -- Multiple instances ------------------------------------------------

    testWidgets('renders multiple CachedImage instances', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                CachedImage(url: 'https://example.com/a.jpg'),
                CachedImage(url: 'https://example.com/b.jpg'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CachedImage), findsNWidgets(2));
    });

    // -- Config parameters preserved --------------------------------------

    testWidgets('preserves maxWidth and maxHeight', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CachedImage(
              url: 'https://example.com/photo.jpg',
              maxWidth: 800,
              maxHeight: 600,
            ),
          ),
        ),
      );

      final cachedImage = tester.widget<CachedImage>(find.byType(CachedImage));
      expect(cachedImage.maxWidth, 800);
      expect(cachedImage.maxHeight, 600);
    });
  });
}
