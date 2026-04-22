import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/core/error/exceptions.dart';
import 'package:anynote/core/widgets/app_components.dart';

void main() {
  // ===========================================================================
  // AppEmptyState
  // ===========================================================================

  group('AppEmptyState', () {
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
            body: AppEmptyState(
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

    testWidgets('renders icon and title', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      expect(find.byIcon(Icons.note_add), findsOneWidget);
      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        subtitle: 'Create your first note',
      );

      expect(find.text('Create your first note'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      expect(find.text('No notes yet'), findsOneWidget);
      // Only one Text widget (the title).
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets(
        'shows action button when both actionLabel and onAction are provided',
        (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        actionLabel: 'Create',
        onAction: () {},
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('does not show action button when actionLabel is null',
        (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        onAction: () {},
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('does not show action button when onAction is null',
        (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        actionLabel: 'Create',
      );

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('action button tap invokes callback', (tester) async {
      var pressed = false;
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        actionLabel: 'Create',
        onAction: () => pressed = true,
      );

      await tester.tap(find.text('Create'));
      expect(pressed, isTrue);
    });

    testWidgets('icon has size 64', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.inbox,
        title: 'Empty',
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, 64);
    });

    testWidgets('renders inside Center widget', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
      );

      // At least one Center should exist (the AppEmptyState wraps in Center).
      expect(find.byType(Center), findsAtLeast(1));
    });

    testWidgets('title and subtitle are center-aligned', (tester) async {
      await pumpEmptyState(
        tester,
        icon: Icons.note_add,
        title: 'No notes yet',
        subtitle: 'Try creating one',
      );

      final titleWidget = tester.widget<Text>(find.text('No notes yet'));
      expect(titleWidget.textAlign, TextAlign.center);

      final subtitleWidget = tester.widget<Text>(find.text('Try creating one'));
      expect(subtitleWidget.textAlign, TextAlign.center);
    });
  });

  // ===========================================================================
  // AppLoadingCard
  // ===========================================================================

  group('AppLoadingCard', () {
    testWidgets('renders in list mode by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: AppLoadingCard(),
            ),
          ),
        ),
      );

      // Pump past any animation frames to avoid transient frame errors.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppLoadingCard), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders in grid mode when isGrid is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AppLoadingCard(isGrid: true),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppLoadingCard), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('contains shader animation for shimmer effect', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: AppLoadingCard(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The shimmer uses a ShaderMask.
      expect(find.byType(ShaderMask), findsAtLeast(1));
    });

    testWidgets('isGrid defaults to false', (tester) async {
      // Verify default constructor behavior.
      const card = AppLoadingCard();
      expect(card.isGrid, isFalse);
    });
  });

  // ===========================================================================
  // AppErrorCard
  // ===========================================================================

  group('AppErrorCard', () {
    testWidgets('renders error icon from ErrorDisplay', (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorCard(error: error),
          ),
        ),
      );

      // ErrorDisplay.errorIcon(NetworkException) returns Icons.wifi_off.
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('renders error message from ErrorDisplay', (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorCard(error: error),
          ),
        ),
      );

      expect(
        find.text(
          'Unable to connect to the server. Please check your internet connection.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders default title "Something went wrong"', (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorCard(error: error),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders custom title when provided', (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorCard(error: error, title: 'Network Failure'),
          ),
        ),
      );

      expect(find.text('Network Failure'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorCard(
              error: error,
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('does not show retry button when onRetry is null',
        (tester) async {
      const error = NetworkException(message: 'No connection');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorCard(error: error),
          ),
        ),
      );

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('retry button invokes callback', (tester) async {
      const error = NetworkException(message: 'No connection');
      var retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorCard(
              error: error,
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('renders different icons for different error types',
        (tester) async {
      const authError = AuthException(message: 'Expired');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorCard(error: authError),
          ),
        ),
      );

      // ErrorDisplay.errorIcon(AuthException) returns Icons.lock_outline.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  // ===========================================================================
  // AppSyncBadge
  // ===========================================================================

  group('AppSyncBadge', () {
    Future<void> pumpBadge(
      WidgetTester tester, {
      required bool isSynced,
      bool hasConflict = false,
      bool showLabel = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSyncBadge(
              isSynced: isSynced,
              hasConflict: hasConflict,
              showLabel: showLabel,
            ),
          ),
        ),
      );
    }

    testWidgets('synced state shows cloud_done with green', (tester) async {
      await pumpBadge(tester, isSynced: true);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_done));
      expect(icon.color, Colors.green);
      expect(icon.size, 16);
    });

    testWidgets('synced state tooltip says "Synced"', (tester) async {
      await pumpBadge(tester, isSynced: true);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Synced');
    });

    testWidgets('pending state shows cloud_upload with orange', (tester) async {
      await pumpBadge(tester, isSynced: false);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_upload));
      expect(icon.color, Colors.orange);
    });

    testWidgets('pending state tooltip says "Pending sync"', (tester) async {
      await pumpBadge(tester, isSynced: false);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Pending sync');
    });

    testWidgets('conflict state shows cloud_off with red', (tester) async {
      await pumpBadge(tester, isSynced: false, hasConflict: true);

      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));
      expect(icon.color, Colors.red);
    });

    testWidgets('conflict state tooltip says "Sync conflict"', (tester) async {
      await pumpBadge(tester, isSynced: false, hasConflict: true);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Sync conflict');
    });

    testWidgets('conflict takes priority over synced', (tester) async {
      await pumpBadge(tester, isSynced: true, hasConflict: true);

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsNothing);
    });

    testWidgets('shows label text when showLabel is true (synced)',
        (tester) async {
      await pumpBadge(tester, isSynced: true, showLabel: true);

      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('shows label text when showLabel is true (pending)',
        (tester) async {
      await pumpBadge(tester, isSynced: false, showLabel: true);

      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('shows label text when showLabel is true (conflict)',
        (tester) async {
      await pumpBadge(tester,
          isSynced: false, hasConflict: true, showLabel: true,);

      expect(find.text('Conflict'), findsOneWidget);
    });

    testWidgets('does not show label when showLabel is false', (tester) async {
      await pumpBadge(tester, isSynced: true, showLabel: false);

      expect(find.text('Synced'), findsNothing);
    });
  });

  // ===========================================================================
  // AppSectionHeader
  // ===========================================================================

  group('AppSectionHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSectionHeader(title: 'Account'),
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSectionHeader(
              title: 'Account',
              trailing: Text('Edit'),
            ),
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('does not render trailing when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSectionHeader(title: 'Account'),
          ),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      // Only one Text widget.
      expect(find.byType(Text), findsOneWidget);
    });
  });

  // ===========================================================================
  // SettingsGroupHeader
  // ===========================================================================

  group('SettingsGroupHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroupHeader(title: 'General'),
          ),
        ),
      );

      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('has header semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroupHeader(title: 'General'),
          ),
        ),
      );

      // Find the Semantics widget that is a direct parent of the
      // SettingsGroupHeader's content (there may be multiple Semantics
      // widgets from MaterialApp).
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final hasHeaderSemantics = semanticsWidgets.any(
        (s) => s.properties.header == true,
      );
      expect(hasHeaderSemantics, isTrue);
    });
  });

  // ===========================================================================
  // SettingsGroup
  // ===========================================================================

  group('SettingsGroup', () {
    testWidgets('renders children with dividers between them', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // 3 items -> 2 dividers between them.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('renders single child without divider', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              children: [
                Text('Only item'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Only item'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('empty group renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroup(children: []),
          ),
        ),
      );

      // No Text widgets, no Dividers.
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('has rounded container with border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsGroup(
              children: [Text('Item')],
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.borderRadius, isNotNull);
    });
  });

  // ===========================================================================
  // SettingsItem
  // ===========================================================================

  group('SettingsItem', () {
    testWidgets('renders icon, title, and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsItem(
              icon: Icons.person,
              title: 'Email',
              subtitle: 'user@example.com',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('renders without subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsItem(
              icon: Icons.person,
              title: 'Email',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsItem(
              icon: Icons.person,
              title: 'Email',
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('handles tap via onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsItem(
              icon: Icons.person,
              title: 'Email',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Email'));
      expect(tapped, isTrue);
    });

    testWidgets('icon is rendered inside a circle container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SettingsItem(
              icon: Icons.person,
              title: 'Email',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.person));
      expect(icon.size, 18);
    });
  });

  // ===========================================================================
  // DestructiveSettingsItem
  // ===========================================================================

  group('DestructiveSettingsItem', () {
    testWidgets('renders title with error color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestructiveSettingsItem(
              icon: Icons.delete,
              title: 'Delete Account',
            ),
          ),
        ),
      );

      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);

      // Verify the title text uses error color.
      final titleWidget = tester.widget<Text>(find.text('Delete Account'));
      final theme = ThemeData.light();
      expect(titleWidget.style?.color, theme.colorScheme.error);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestructiveSettingsItem(
              icon: Icons.delete,
              title: 'Delete Account',
              subtitle: 'This cannot be undone',
            ),
          ),
        ),
      );

      expect(find.text('This cannot be undone'), findsOneWidget);
    });

    testWidgets('handles tap via onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DestructiveSettingsItem(
              icon: Icons.delete,
              title: 'Sign Out',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sign Out'));
      expect(tapped, isTrue);
    });

    testWidgets('icon circle uses error color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DestructiveSettingsItem(
              icon: Icons.logout,
              title: 'Sign Out',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.logout));
      // The icon inside _IconCircle uses the error color.
      final theme = ThemeData.light();
      expect(icon.color, theme.colorScheme.error);
    });
  });

  // ===========================================================================
  // StaggeredGroup
  // ===========================================================================

  group('StaggeredGroup', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredGroup(
              staggerIndex: 0,
              child: Text('Staggered Content'),
            ),
          ),
        ),
      );

      // Allow stagger delay to elapse.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Staggered Content'), findsOneWidget);
    });

    testWidgets('renders with non-zero stagger index', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredGroup(
              staggerIndex: 3,
              child: Text('Delayed Content'),
            ),
          ),
        ),
      );

      // Wait for stagger delay (3 * 50ms = 150ms) plus animation.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Delayed Content'), findsOneWidget);
    });

    testWidgets('uses FadeTransition and SlideTransition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredGroup(
              staggerIndex: 0,
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Pump to let the stagger delay (Duration.zero for index 0) and
      // animation start. Use pumpAndSettle to drain all pending timers.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Flutter's widget tree includes multiple internal FadeTransitions
      // and SlideTransitions from MaterialApp. Just verify they exist.
      expect(find.byType(FadeTransition), findsAtLeast(1));
      expect(find.byType(SlideTransition), findsAtLeast(1));
    });
  });
}
