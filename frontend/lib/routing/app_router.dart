import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/notes/presentation/notes_list_screen.dart';
import '../features/notes/presentation/note_detail_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/compose/presentation/compose_screen.dart';
import '../features/compose/presentation/cluster_screen.dart';
import '../features/compose/presentation/outline_screen.dart';
import '../features/compose/presentation/compose_editor_screen.dart';
import '../features/publish/presentation/publish_screen.dart';
import '../features/publish/presentation/publish_history_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/llm_config_screen.dart';
import '../features/settings/presentation/platform_connection_screen.dart';
import '../features/settings/presentation/encryption_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/notes',
  redirect: (context, state) {
    // TODO: Check auth state from Riverpod
    // final isLoggedIn = ... ;
    // if (!isLoggedIn && !state.matchedLocation.startsWith('/auth')) return '/auth/login';
    // if (isLoggedIn && state.matchedLocation.startsWith('/auth')) return '/notes';
    return null;
  },
  routes: [
    // Auth routes (no shell)
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Main app with bottom navigation shell
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // Notes
        GoRoute(
          path: '/notes',
          builder: (context, state) => const NotesListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const NoteEditorScreen(),
            ),
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => NoteDetailScreen(
                noteId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),

        // Compose (AI)
        GoRoute(
          path: '/compose',
          builder: (context, state) => const ComposeScreen(),
          routes: [
            GoRoute(
              path: 'cluster/:id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => ClusterScreen(
                sessionId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'outline/:id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => OutlineScreen(
                sessionId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'editor/:id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => ComposeEditorScreen(
                sessionId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),

        // Publish
        GoRoute(
          path: '/publish',
          builder: (context, state) => const PublishScreen(),
          routes: [
            GoRoute(
              path: 'history',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const PublishHistoryScreen(),
            ),
          ],
        ),

        // Settings
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'llm',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const LLMConfigScreen(),
            ),
            GoRoute(
              path: 'platforms',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const PlatformConnectionScreen(),
            ),
            GoRoute(
              path: 'security',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const EncryptionScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Main shell with bottom navigation bar.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.note_outlined), selectedIcon: Icon(Icons.note), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Compose'),
          NavigationDestination(icon: Icon(Icons.publish_outlined), selectedIcon: Icon(Icons.publish), label: 'Publish'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/notes')) return 0;
    if (location.startsWith('/compose')) return 1;
    if (location.startsWith('/publish')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/notes');
      case 1: context.go('/compose');
      case 2: context.go('/publish');
      case 3: context.go('/settings');
    }
  }
}
