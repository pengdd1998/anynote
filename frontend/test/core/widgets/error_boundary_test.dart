import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    testWidgets('renders child when no error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: Text('Hello World'),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders child widget tree correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(
            child: Column(
              children: [
                Icon(Icons.star),
                Text('Content'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('ErrorBoundary is a StatefulWidget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ErrorBoundary(child: SizedBox()),
        ),
      );

      // Verify the ErrorBoundary widget is present and wraps the child.
      expect(find.byType(ErrorBoundary), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
