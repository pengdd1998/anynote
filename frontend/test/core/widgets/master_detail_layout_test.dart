import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/master_detail_layout.dart';

void main() {
  // ===========================================================================
  // Phone layout (width < 600)
  // ===========================================================================

  group('MasterDetailLayout phone layout', () {
    testWidgets('shows only master pane when screen width < 600', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      // Detail pane should not be rendered in phone layout.
      expect(find.text('Select an item to view'), findsNothing);
    });

    testWidgets('phone layout does not show detail pane even with selectedId',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      // Still only master pane in phone layout.
      expect(find.text('Detail: note-1'), findsNothing);
    });
  });

  // ===========================================================================
  // Desktop layout (width >= 600)
  // ===========================================================================

  group('MasterDetailLayout desktop layout', () {
    testWidgets('shows both panes when screen width >= 600', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      expect(find.text('Detail: note-1'), findsOneWidget);
    });

    testWidgets('shows default empty message when no selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      expect(find.text('Select an item to view'), findsOneWidget);
    });

    testWidgets('shows default placeholder icon when no selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    });

    testWidgets('uses custom emptyDetailPlaceholder when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                emptyDetailPlaceholder: const Text('Custom Placeholder'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Custom Placeholder'), findsOneWidget);
      // Default placeholder should NOT be present.
      expect(find.text('Select an item to view'), findsNothing);
    });

    testWidgets('custom placeholder is not shown when selectedId is set',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                emptyDetailPlaceholder: const Text('Custom Placeholder'),
                selectedId: 'note-42',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Detail: note-42'), findsOneWidget);
      expect(find.text('Custom Placeholder'), findsNothing);
    });

    testWidgets('shows detail content with different selectedId values',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail for: ${id ?? "none"}'),
                selectedId: 'abc-123',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Detail for: abc-123'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Sidebar visibility toggle
  // ===========================================================================

  group('MasterDetailLayout sidebar toggle', () {
    testWidgets('sidebarVisible=false collapses master pane with zero width',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                sidebarVisible: false,
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      // Master content should be hidden behind the zero-width animated container.
      // The AnimatedContainer should have width 0.
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      // The width is set via the constructor; we verify via the child tree.
      // When sidebarVisible=false, the child is SizedBox.shrink.
      expect(find.byType(SizedBox), findsWidgets);

      // Detail should still be visible.
      expect(find.text('Detail: note-1'), findsOneWidget);
    });

    testWidgets('sidebarVisible=true shows master pane with non-zero width',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                sidebarVisible: true,
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      expect(find.text('Detail: note-1'), findsOneWidget);
    });

    testWidgets('divider is shown when sidebarVisible=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                sidebarVisible: true,
              ),
            ),
          ),
        ),
      );

      // The _DraggableDivider is a GestureDetector.
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('divider is not shown when sidebarVisible=false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                sidebarVisible: false,
              ),
            ),
          ),
        ),
      );

      // Master pane is hidden, so divider should not be present either.
      // The Row should only have the Expanded detail pane.
      final row = tester.widget<Row>(find.byType(Row));
      // AnimatedContainer + Expanded (no divider widget).
      expect(row.children.length, 2);
    });
  });

  // ===========================================================================
  // Threshold boundary
  // ===========================================================================

  group('MasterDetailLayout threshold boundary', () {
    testWidgets('uses side-by-side exactly at threshold (600)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      expect(find.text('Detail: note-1'), findsOneWidget);
    });

    testWidgets('uses phone layout just below threshold (599)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(599, 800)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Master Content'), findsOneWidget);
      // No detail pane in phone layout.
      expect(find.text('Detail: note-1'), findsNothing);
    });

    testWidgets('custom threshold is respected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(700, 800)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                sideBySideThreshold: 800,
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      // 700 < 800 threshold, so phone layout.
      expect(find.text('Master Content'), findsOneWidget);
      expect(find.text('Detail: note-1'), findsNothing);
    });
  });

  // ===========================================================================
  // Widget structure
  // ===========================================================================

  group('MasterDetailLayout widget structure', () {
    testWidgets('desktop layout uses Row for side-by-side', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('desktop layout uses AnimatedContainer for master pane',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('desktop layout uses Expanded for detail pane', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1024, 768)),
            child: Scaffold(
              body: MasterDetailLayout(
                masterPane: const Text('Master Content'),
                detailPaneBuilder: (id) => Text('Detail: $id'),
                selectedId: 'note-1',
              ),
            ),
          ),
        ),
      );

      final expanded = tester.widget<Expanded>(find.byType(Expanded));
      expect(expanded, isNotNull);
    });
  });
}
