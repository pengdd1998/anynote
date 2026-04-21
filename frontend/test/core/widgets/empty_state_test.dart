import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    /// Pumps the EmptyState inside a minimal MaterialApp.
    Future<void> pumpEmptyState(
      WidgetTester tester, {
      required IconData icon,
      required String title,
      String? subtitle,
      String? actionLabel,
      VoidCallback? onAction,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: icon,
              title: title,
              subtitle: subtitle,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
          ),
        ),
      );
    }

    // -- Basic rendering ----------------------------------------------

    testWidgets('renders title text', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('renders the provided icon', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      expect(find.byIcon(Icons.note_add), findsOneWidget);
    });

    testWidgets('renders icon at size 64', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.inbox,
        title: 'Empty',
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, 64);
    });

    testWidgets('renders inside a Center widget', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      expect(find.byType(Center), findsWidgets);
    });

    // -- Subtitle -----------------------------------------------------

    testWidgets('renders subtitle when provided', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        subtitle: 'Create your first note',
      );

      expect(find.text('Create your first note'), findsOneWidget);
    });

    testWidgets('does not render subtitle text when null', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        // subtitle intentionally omitted
      );

      // Only the title text should exist; no secondary text.
      expect(find.text('No notes yet'), findsOneWidget);
      // There should be exactly two Text widgets: the title only (since no
      // subtitle and no action label).
      expect(find.byType(Text), findsOneWidget);
    });

    // -- Action button ------------------------------------------------

    testWidgets('renders action button when actionLabel and onAction are provided',
        (tester) async {
      var pressed = false;
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        actionLabel: 'New Note',
        onAction: () => pressed = true,
      );

      expect(find.text('New Note'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('action button callback is invoked on tap', (tester) async {
      var pressed = false;
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        actionLabel: 'New Note',
        onAction: () => pressed = true,
      );

      await tester.tap(find.text('New Note'));
      expect(pressed, isTrue);
    });

    testWidgets('does not render action button when actionLabel is null',
        (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        onAction: () {},
        // actionLabel intentionally omitted
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('does not render action button when onAction is null',
        (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        actionLabel: 'New Note',
        // onAction intentionally omitted
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    // -- Different configurations -------------------------------------

    testWidgets('renders with a different icon', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.cloud_off,
        title: 'No connection',
        subtitle: 'Check your network settings',
      );

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Check your network settings'), findsOneWidget);
    });

    testWidgets('renders with tag icon and subtitle', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.label_off,
        title: 'No tags',
        subtitle: 'Tags will appear here once created',
      );

      expect(find.byIcon(Icons.label_off), findsOneWidget);
      expect(find.text('No tags'), findsOneWidget);
      expect(find.text('Tags will appear here once created'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders full configuration with all fields', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.search_off,
        title: 'No results',
        subtitle: 'Try a different search term',
        actionLabel: 'Clear search',
        onAction: () {},
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Try a different search term'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    // -- Text alignment -----------------------------------------------

    testWidgets('title text is center-aligned', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      final titleWidget = tester.widget<Text>(find.text('No notes yet'));
      expect(titleWidget.textAlign, TextAlign.center);
    });

    testWidgets('subtitle text is center-aligned', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        subtitle: 'Create your first note',
      );

      final subtitleWidget =
          tester.widget<Text>(find.text('Create your first note'));
      expect(subtitleWidget.textAlign, TextAlign.center);
    });
  });
}
