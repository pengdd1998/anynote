import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/page_transitions.dart';
import '../core/widgets/adaptive_scaffold.dart';
import '../core/widgets/offline_banner.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
// Eager imports: on the default user path, loaded at startup.
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/recovery_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/notes/presentation/notes_list_screen.dart';
import '../features/notes/presentation/note_detail_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/notes/presentation/version_history_screen.dart';
import '../features/notes/presentation/markdown_preview_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/collections/presentation/collections_list_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/share/presentation/shared_note_viewer.dart';
import '../features/share/presentation/discover_screen.dart';
import '../features/search/presentation/advanced_search_screen.dart';

// Deferred imports: heavy or rarely visited screens loaded on demand.
import '../features/compose/presentation/compose_screen.dart' deferred as compose;
import '../features/compose/presentation/cluster_screen.dart' deferred as cluster;
import '../features/compose/presentation/outline_screen.dart' deferred as outline;
import '../features/compose/presentation/compose_editor_screen.dart'
    deferred as compose_editor;
import '../features/publish/presentation/publish_screen.dart' deferred as publish;
import '../features/publish/presentation/publish_history_screen.dart'
    deferred as publish_history;
import '../features/settings/presentation/llm_config_screen.dart'
    deferred as llm_config;
import '../features/settings/presentation/platform_connection_screen.dart'
    deferred as platform_conn;
import '../features/settings/presentation/encryption_screen.dart'
    deferred as encryption;
import '../features/settings/presentation/import_screen.dart'
    deferred as import_screen;
import '../features/settings/presentation/restore_screen.dart'
    deferred as restore;

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
    // Includes both the public shared note viewer and the share
    // extension receiver (anynote://share/received).
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
    // Note: /share/received must come before /share/:id to avoid the
    // dynamic segment matching "received" as a share ID.
    GoRoute(
      path: '/share/received',
      redirect: (context, state) {
        // Intermediary route: the share extension deep link lands here.
        // The actual content is consumed by ReceiveShareService which
        // navigates to the note editor via the stream listener in main.dart.
        // Redirect to the notes list; the stream listener will push the editor.
        return '/notes';
      },
    ),
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
                final shareContent =
                    state.uri.queryParameters['shareContent'];
                return slideTransition(
                  NoteEditorScreen(
                    initialContent: shareContent ?? templateContent,
                  ),
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

        // Compose (AI) -- deferred, heavy dependency tree.
        GoRoute(
          path: '/compose',
          pageBuilder: (context, state) => fadeThroughTransition(
            _DeferredLoader(
              load: compose.loadLibrary(),
              builder: () => compose.ComposeScreen(),
            ),
          ),
          routes: [
            GoRoute(
              path: 'cluster/:id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: cluster.loadLibrary(),
                  builder: () => cluster.ClusterScreen(
                    sessionId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ),
            GoRoute(
              path: 'outline/:id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: outline.loadLibrary(),
                  builder: () => outline.OutlineScreen(
                    sessionId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ),
            GoRoute(
              path: 'editor/:id',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: compose_editor.loadLibrary(),
                  builder: () => compose_editor.ComposeEditorScreen(
                    sessionId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Publish -- deferred, platform adapters rarely needed.
        GoRoute(
          path: '/publish',
          pageBuilder: (context, state) => fadeThroughTransition(
            _DeferredLoader(
              load: publish.loadLibrary(),
              builder: () => publish.PublishScreen(),
            ),
          ),
          routes: [
            GoRoute(
              path: 'history',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: publish_history.loadLibrary(),
                  builder: () => publish_history.PublishHistoryScreen(),
                ),
              ),
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
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: llm_config.loadLibrary(),
                  builder: () => llm_config.LLMConfigScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'platforms',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: platform_conn.loadLibrary(),
                  builder: () => platform_conn.PlatformConnectionScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'security',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: encryption.loadLibrary(),
                  builder: () => encryption.EncryptionScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'import',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: import_screen.loadLibrary(),
                  builder: () => import_screen.ImportScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'restore',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: restore.loadLibrary(),
                  builder: () => restore.RestoreScreen(),
                ),
              ),
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
class _DesktopShell extends ConsumerWidget {
  final Widget child;
  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _selectedIndex(context);
    final l10n = AppLocalizations.of(context);
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
            destinations: [
              NavigationRailDestination(
                icon: const Tooltip(
                  message: 'Notes',
                  preferBelow: false,
                  child: Icon(Icons.note_outlined),
                ),
                selectedIcon: const Tooltip(
                  message: 'Notes',
                  preferBelow: false,
                  child: Icon(Icons.note),
                ),
                label: Semantics(
                  label: l10n?.notesTabLabel ?? 'Notes',
                  child: const Text('Notes'),
                ),
              ),
              NavigationRailDestination(
                icon: const Tooltip(
                  message: 'Compose',
                  preferBelow: false,
                  child: Icon(Icons.auto_awesome_outlined),
                ),
                selectedIcon: const Tooltip(
                  message: 'Compose',
                  preferBelow: false,
                  child: Icon(Icons.auto_awesome),
                ),
                label: Semantics(
                  label: l10n?.composeTabLabel ?? 'Compose',
                  child: const Text('Compose'),
                ),
              ),
              NavigationRailDestination(
                icon: const Tooltip(
                  message: 'Publish',
                  preferBelow: false,
                  child: Icon(Icons.publish_outlined),
                ),
                selectedIcon: const Tooltip(
                  message: 'Publish',
                  preferBelow: false,
                  child: Icon(Icons.publish),
                ),
                label: Semantics(
                  label: l10n?.publishTabLabel ?? 'Publish',
                  child: const Text('Publish'),
                ),
              ),
              NavigationRailDestination(
                icon: const Tooltip(
                  message: 'Settings',
                  preferBelow: false,
                  child: Icon(Icons.settings_outlined),
                ),
                selectedIcon: const Tooltip(
                  message: 'Settings',
                  preferBelow: false,
                  child: Icon(Icons.settings),
                ),
                label: Semantics(
                  label: l10n?.settingsTabLabel ?? 'Settings',
                  child: const Text('Settings'),
                ),
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

/// Widget that loads a deferred library and shows a loading indicator until
/// the library is ready. After the first load, subsequent visits resolve
/// immediately because [LibraryLoader.load] is a no-op once loaded.
class _DeferredLoader extends StatefulWidget {
  final Future<void> load;
  final Widget Function() builder;

  const _DeferredLoader({required this.load, required this.builder});

  @override
  State<_DeferredLoader> createState() => _DeferredLoaderState();
}

class _DeferredLoaderState extends State<_DeferredLoader> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.load.then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.builder();
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
