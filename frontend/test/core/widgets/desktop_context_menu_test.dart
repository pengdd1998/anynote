import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/desktop_context_menu.dart';

void main() {
  group('DesktopContextMenu', () {
    testWidgets('renders child without GestureDetector on mobile',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopContextMenu(
            items: const [
              PopupMenuItem(value: 'copy', child: Text('Copy')),
            ],
            onSelected: (_) {},
            child: const Text('Target'),
          ),
        ),
      );

      expect(find.text('Target'), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('wraps child with GestureDetector on desktop (Linux)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopContextMenu(
            items: const [
              PopupMenuItem(value: 'copy', child: Text('Copy')),
            ],
            onSelected: (_) {},
            child: const Text('Target'),
          ),
        ),
      );

      expect(find.text('Target'), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('wraps child with GestureDetector on desktop (macOS)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopContextMenu(
            items: const [
              PopupMenuItem(value: 'copy', child: Text('Copy')),
            ],
            onSelected: (_) {},
            child: const Text('Target'),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('wraps child with GestureDetector on desktop (Windows)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopContextMenu(
            items: const [
              PopupMenuItem(value: 'copy', child: Text('Copy')),
            ],
            onSelected: (_) {},
            child: const Text('Target'),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('no GestureDetector on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopContextMenu(
            items: const [
              PopupMenuItem(value: 'copy', child: Text('Copy')),
            ],
            onSelected: (_) {},
            child: const Text('Target'),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNothing);

      debugDefaultTargetPlatformOverride = null;
    });
  });
}
