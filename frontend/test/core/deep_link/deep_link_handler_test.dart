import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anynote/core/deep_link/deep_link_handler.dart';

void main() {
  late GoRouter goRouter;

  setUp(() {
    goRouter = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/notes/new',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/notes/:id',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/share/received',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/share/:id',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
      initialLocation: '/',
    );
  });

  Widget _buildTestApp() {
    return MaterialApp.router(
      routerConfig: goRouter,
    );
  }

  // -- Unit tests for _isValidSegment logic (tested via handleUri behavior) --
  // Since _isValidSegment and _isValidId are private, we test them indirectly
  // through handleUri. We verify that invalid URIs do not cause navigation.

  group('DeepLinkHandler - note links', () {
    testWidgets('navigates to /notes/new for anynote://notes/new',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // BuildContext is available after pumping
      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/new'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/notes/new');
    });

    testWidgets('navigates to /notes/new for anynote://notes (single segment)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/notes/new');
    });

    testWidgets('navigates to specific note with valid UUID', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/550e8400-e29b-41d4-a716-446655440000'),
      );

      await tester.pumpAndSettle();
      expect(
        goRouter.state.uri.path,
        '/notes/550e8400-e29b-41d4-a716-446655440000',
      );
    });

    testWidgets('navigates to note with short hex id', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/abc123'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/notes/abc123');
    });

    testWidgets('rejects note id with uppercase letters', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      // Uppercase hex is rejected by _isValidId because the pattern only
      // allows [a-f0-9-]
      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/ABC123'),
      );

      await tester.pumpAndSettle();
      // Should stay on root, navigation rejected
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('rejects note id with special characters', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/note<script>'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('rejects note id with path traversal', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/../etc/passwd'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('rejects overly long note id', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      final longId = 'a' * 300;
      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/$longId'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });
  });

  group('DeepLinkHandler - share links', () {
    testWidgets('navigates to /share/received for anynote://share/received',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://share/received'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/share/received');
    });

    testWidgets('navigates to share with valid UUID id', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://share/abc123-def456'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/share/abc123-def456');
    });

    testWidgets('rejects share id with invalid characters', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://share/invalid!id'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('does nothing for share with wrong segment count',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      // share/one/two has 3 segments, which is not handled
      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://share/one/two'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });
  });

  group('DeepLinkHandler - edge cases', () {
    testWidgets('does nothing for empty path segments', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('does nothing for unknown first segment', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://unknown/path'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('does nothing for first segment with special characters',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      // First segment has a space, which fails _isValidSegment
      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://bad%20segment/test'),
      );

      await tester.pumpAndSettle();
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('handles notes with three segments (ignores extra)',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      // notes/new/extra -- segments.length > 2, so the switch case for
      // 'notes' does not match any condition.
      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/new/extra'),
      );

      await tester.pumpAndSettle();
      // No navigation should occur (stays at root)
      expect(goRouter.state.uri.path, '/');
    });

    testWidgets('handles notes with empty second segment', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SizedBox).first);

      // notes/  -> second segment is empty, _isValidId rejects it
      DeepLinkHandler.handleUri(
        context,
        Uri.parse('anynote://notes/'),
      );

      await tester.pumpAndSettle();
      // segments would be ['notes'] (trailing slash produces no extra segment)
      // so segments.length == 1, which triggers the "new" navigation
      expect(goRouter.state.uri.path, '/notes/new');
    });
  });
}
