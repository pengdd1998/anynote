import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/page_transitions.dart';
import '../core/widgets/adaptive_scaffold.dart';
import '../core/widgets/offline_banner.dart';
import '../main.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/notes/presentation/notes_list_screen.dart';
import '../features/notes/presentation/note_detail_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/notes/presentation/version_history_screen.dart';
import '../features/notes/presentation/markdown_preview_screen.dart';
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
import '../features/settings/presentation/import_screen.dart';
import '../features/settings/presentation/restore_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/recovery_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/collections/presentation/collections_list_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/share/presentation/shared_note_viewer.dart';
import '../features/share/presentation/discover_screen.dart';
import '../features/search/presentation/advanced_search_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/notes',
  redirect: (context, state) {
    final isLoggedIn = globalContainer.read(authStateProvider);
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    final isOnboarding = state.matchedLocation == '/onboarding';
    final isShareRoute = state.matchedLocation.startsWith('/share');
    final isDiscoverRoute = state.matchedLocation == '/discover';

    // Share route is always accessible (no auth required).
    if (isShareRoute) return null;

    // Discover route is always accessible (no auth required).
    if (isDiscoverRoute) return null;

    // If user is authenticated, onboarding is irrelevant.
    if (isLoggedIn) {
      if (isAuthRoute || isOnboarding) return '/notes';
      return null;
    }

    // Not logged in and trying to access a protected route.
    // Check if onboarding has been seen.
    if (!isAuthRoute && !isOnboarding) {
      final hasSeen = globalContainer.read(hasSeenOnboardingProvider);
      if (!hasSeen) return '/onboarding';
      return '/auth/login';
    }

    return null;
  },
  routes: [
    // Onboarding route (no shell)
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) =>
          slideTransition(const OnboardingScreen()),
    ),

    // Auth routes (no shell)
    GoRoute(
      path: '/auth/login',
      pageBuilder: (context, state) =>
          slideTransition(const LoginScreen()),
    ),
    GoRoute(
      path: '/auth/register',
      pageBuilder: (context, state) =>
          slideTransition(const RegisterScreen()),
    ),
    GoRoute(
      path: '/auth/recover',
      pageBuilder: (context, state) =>
          slideTransition(const RecoveryScreen()),
    ),

    // Shared note viewer (public, no auth required)
    GoRoute(
      path: '/share/:id',
      pageBuilder: (context, state) => slideTransition(
        SharedNoteViewer(
          shareId: state.pathParameters['id']!,
          shareKeyFragment: state.uri.fragment.isNotEmpty
              ? state.uri.fragment
              : null,
        ),
      ),
    ),

    // Collections routes (pushed from notes screen, no bottom nav shell)
    GoRoute(
      path: '/collections',
      pageBuilder: (context, state) =>
          slideTransition(const CollectionsListScreen()),
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => slideTransition(
            CollectionDetailScreen(
              collectionId: state.pathParameters['id']!,
            ),
          ),
        ),
      ],
    ),

    // Advanced search (pushed from notes screen, no bottom nav shell)
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) =>
          slideTransition(const AdvancedSearchScreen()),
    ),

    // Discover feed (public shared notes, accessible with or without auth)
    GoRoute(
      path: '/discover',
      pageBuilder: (context, state) =>
          slideTransition(const DiscoverScreen()),
    ),

    // Main app with bottom navigation shell
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        // Notes
        GoRoute(
          path: '/notes',
          pageBuilder: (context, state) =>
              fadeThroughTransition(const NotesListScreen()),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) {
                final templateContent =
                    state.uri.queryParameters['templateContent'];
                return slideTransition(
                  NoteEditorScreen(initialContent: templateContent),
                );
              },
            ),
            GoRoute(
              path: ':id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                NoteDetailScreen(
                  noteId: state.pathParameters['id']!,
                ),
              ),
              routes: [
                GoRoute(
                  path: 'history',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransition(
                    VersionHistoryScreen(
                      noteId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'preview',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransition(
                    MarkdownPreviewScreen(
                      noteId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Compose (AI)
        GoRoute(
          path: '/compose',
          pageBuilder: (context, state) =>
              fadeThroughTransition(const ComposeScreen()),
          routes: [
            GoRoute(
              path: 'cluster/:id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                ClusterScreen(
                  sessionId: state.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: 'outline/:id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                OutlineScreen(
                  sessionId: state.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: 'editor/:id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                ComposeEditorScreen(
                  sessionId: state.pathParameters['id']!,
                ),
              ),
            ),
          ],
        ),

        // Publish
        GoRoute(
          path: '/publish',
          pageBuilder: (context, state) =>
              fadeThroughTransition(const PublishScreen()),
          routes: [
            GoRoute(
              path: 'history',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const PublishHistoryScreen()),
            ),
          ],
        ),

        // Settings
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              fadeThroughTransition(const SettingsScreen()),
          routes: [
            GoRoute(
              path: 'llm',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const LLMConfigScreen()),
            ),
            GoRoute(
              path: 'platforms',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const PlatformConnectionScreen()),
            ),
            GoRoute(
              path: 'security',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const EncryptionScreen()),
            ),
            GoRoute(
              path: 'import',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const ImportScreen()),
            ),
            GoRoute(
              path: 'restore',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const RestoreScreen()),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Main shell with bottom navigation bar on phone and a side NavigationRail
/// on tablet/desktop, plus an offline banner.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      phoneLayout: _PhoneShell(child: child),
      tabletLayout: _DesktopShell(child: child),
      desktopLayout: _DesktopShell(child: child),
    );
  }
}

/// Phone layout: bottom NavigationBar.
class _PhoneShell extends StatelessWidget {
  final Widget child;
  const _PhoneShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
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
}

/// Desktop/tablet layout: NavigationRail on the left side.
class _DesktopShell extends StatelessWidget {
  final Widget child;
  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                _onDestinationSelected(context, index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'AnyNote',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.note_outlined),
                selectedIcon: Icon(Icons.note),
                label: Text('Notes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: Text('Compose'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.publish_outlined),
                selectedIcon: Icon(Icons.publish),
                label: Text('Publish'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                const OfflineBanner(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    case 0:
      context.go('/notes');
    case 1:
      context.go('/compose');
    case 2:
      context.go('/publish');
    case 3:
      context.go('/settings');
  }
}
