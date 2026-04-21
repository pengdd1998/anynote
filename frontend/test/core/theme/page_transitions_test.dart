import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anynote/core/theme/page_transitions.dart';

void main() {
  // ===========================================================================
  // fadeThroughTransition
  // ===========================================================================

  group('fadeThroughTransition', () {
    test('returns a CustomTransitionPage', () {
      const child = SizedBox();
      final page = fadeThroughTransition(child);

      expect(page, isA<CustomTransitionPage<void>>());
    });

    test('has transition duration of 300ms', () {
      const child = SizedBox();
      final page = fadeThroughTransition(child);

      expect(page.transitionDuration, const Duration(milliseconds: 300));
    });

    test('has reverse transition duration of 300ms', () {
      const child = SizedBox();
      final page = fadeThroughTransition(child);

      expect(page.reverseTransitionDuration, const Duration(milliseconds: 300));
    });

    test('contains the provided child widget', () {
      const child = Text('Test Child');
      final page = fadeThroughTransition(child);

      expect(page.child, isA<Text>());
      expect((page.child as Text).data, 'Test Child');
    });

    testWidgets('can be used as GoRouter pageBuilder', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                fadeThroughTransition(const Scaffold(body: Text('Home'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('transition produces FadeTransition widgets during animation',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                fadeThroughTransition(const Scaffold(body: Text('Page A'))),
          ),
          GoRoute(
            path: '/b',
            pageBuilder: (context, state) =>
                fadeThroughTransition(const Scaffold(body: Text('Page B'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      expect(find.text('Page A'), findsOneWidget);

      // Navigate to trigger the transition.
      router.go('/b');
      await tester.pump();

      // During the transition, FadeTransition widgets should exist.
      expect(find.byType(FadeTransition), findsWidgets);

      // Let the transition complete.
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsOneWidget);
    });
  });

  // ===========================================================================
  // slideTransition
  // ===========================================================================

  group('slideTransition', () {
    test('returns a Page<void>', () {
      const child = SizedBox();
      final page = slideTransition(child);

      expect(page, isA<Page<void>>());
    });

    test('returns CustomTransitionPage on non-iOS (test environment)', () {
      const child = SizedBox();
      final page = slideTransition(child);

      // Test environment runs on non-iOS, so should return CustomTransitionPage.
      expect(page, isA<CustomTransitionPage<void>>());
    });

    test('has forward duration of 300ms', () {
      const child = SizedBox();
      final page = slideTransition(child) as CustomTransitionPage<void>;

      expect(page.transitionDuration, const Duration(milliseconds: 300));
    });

    test('has reverse duration of 250ms', () {
      const child = SizedBox();
      final page = slideTransition(child) as CustomTransitionPage<void>;

      expect(page.reverseTransitionDuration, const Duration(milliseconds: 250));
    });

    test('contains the provided child widget', () {
      const child = Text('Slide Page');
      final page = slideTransition(child);

      expect(page.child, isA<Text>());
      expect((page.child as Text).data, 'Slide Page');
    });

    testWidgets('can be used as GoRouter pageBuilder', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                slideTransition(const Scaffold(body: Text('Home'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('transition produces SlideTransition and FadeTransition during animation',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                slideTransition(const Scaffold(body: Text('Page A'))),
          ),
          GoRoute(
            path: '/b',
            pageBuilder: (context, state) =>
                slideTransition(const Scaffold(body: Text('Page B'))),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      expect(find.text('Page A'), findsOneWidget);

      // Navigate to trigger the transition.
      router.go('/b');
      await tester.pump();

      // During the transition, SlideTransition and FadeTransition should exist.
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      // Let the transition complete.
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsOneWidget);
    });
  });

  // ===========================================================================
  // Integration: both transitions in a GoRouter
  // ===========================================================================

  group('page transitions integration', () {
    testWidgets('GoRouter navigates with fadeThrough and slide transitions',
        (tester) async {
      final router = GoRouter(
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) {
              return Scaffold(body: navigationShell);
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    pageBuilder: (context, state) =>
                        fadeThroughTransition(const Text('Tab 1')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/tab2',
                    pageBuilder: (context, state) =>
                        fadeThroughTransition(const Text('Tab 2')),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/detail',
            pageBuilder: (context, state) =>
                slideTransition(const Text('Detail Page')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      expect(find.text('Tab 1'), findsOneWidget);

      // Navigate to detail with slide transition.
      router.go('/detail');
      await tester.pumpAndSettle();

      expect(find.text('Detail Page'), findsOneWidget);
    });

    testWidgets('back navigation completes without error', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                fadeThroughTransition(const Text('Home')),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                slideTransition(const Text('Settings')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      expect(find.text('Home'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      // Go back.
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
