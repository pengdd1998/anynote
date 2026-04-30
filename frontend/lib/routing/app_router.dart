import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_icons.dart';
import '../core/theme/page_transitions.dart';
import '../core/widgets/adaptive_scaffold.dart';
import '../core/widgets/offline_banner.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../core/sync/sync_engine.dart' show SyncConflict;
// Eager imports: on the default user path, loaded at startup.
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/recovery_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/notes/presentation/notes_list_screen.dart';
import '../features/notes/presentation/note_detail_screen.dart';
import '../features/notes/presentation/note_editor_screen.dart';
import '../features/notes/presentation/version_history_screen.dart';
import '../features/notes/presentation/widgets/version_diff_screen.dart';
import '../features/notes/presentation/widgets/note_compare_screen.dart';
import '../features/notes/presentation/markdown_preview_screen.dart';
import '../features/notes/presentation/trash_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/keyboard_shortcuts_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/collections/presentation/collections_list_screen.dart';
import '../features/collections/presentation/collection_detail_screen.dart';
import '../features/share/presentation/shared_note_viewer.dart';
import '../features/share/presentation/discover_screen.dart';
import '../features/search/presentation/advanced_search_screen.dart';
import '../features/tags/presentation/tags_screen.dart';

// Deferred imports: heavy or rarely visited screens loaded on demand.
import '../features/compose/presentation/compose_screen.dart'
    deferred as compose;
import '../features/compose/presentation/cluster_screen.dart'
    deferred as cluster;
import '../features/compose/presentation/outline_screen.dart'
    deferred as outline;
import '../features/compose/presentation/compose_editor_screen.dart'
    deferred as compose_editor;
import '../features/publish/presentation/publish_screen.dart'
    deferred as publish;
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
import '../features/settings/presentation/plan_screen.dart'
    deferred as plan_screen;
import '../features/settings/presentation/profile_screen.dart'
    deferred as profile_screen;
import '../features/settings/presentation/image_management_screen.dart';
import '../features/ai_chat/presentation/ai_chat_screen.dart'
    deferred as ai_chat;
import '../features/ai_chat/presentation/ai_agent_screen.dart';
import '../features/notes/presentation/widgets/note_graph_screen.dart';
import '../features/notes/presentation/widgets/properties_dashboard.dart';
import '../features/notes/presentation/widgets/statistics_screen.dart';
import '../features/notes/presentation/daily_notes_screen.dart';
import '../features/notes/presentation/reminders_screen.dart';
import '../features/notes/presentation/widgets/template_management_screen.dart';
import '../features/notes/presentation/conflict_resolution_screen.dart';
import '../features/snippets/presentation/snippets_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/notes',
  redirect: (context, state) {
    // Container not yet initialized (first frame). Skip redirect to avoid
    // LateInitializationError — the microtask in initState will set
    // containerReady and trigger a rebuild that re-evaluates this redirect.
    if (!containerReady) return null;

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
      pageBuilder: (context, state) => slideTransition(const LoginScreen()),
    ),
    GoRoute(
      path: '/auth/register',
      pageBuilder: (context, state) => slideTransition(const RegisterScreen()),
    ),
    GoRoute(
      path: '/auth/recover',
      pageBuilder: (context, state) => slideTransition(const RecoveryScreen()),
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
          shareKeyFragment:
              state.uri.fragment.isNotEmpty ? state.uri.fragment : null,
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

    // Tags management (pushed from settings, no bottom nav shell)
    GoRoute(
      path: '/tags',
      pageBuilder: (context, state) => slideTransition(const TagsScreen()),
    ),

    // Code Snippets management (pushed from notes screen)
    GoRoute(
      path: '/snippets',
      pageBuilder: (context, state) => slideTransition(const SnippetsScreen()),
    ),

    // Discover feed (public shared notes, accessible with or without auth)
    GoRoute(
      path: '/discover',
      pageBuilder: (context, state) => slideTransition(const DiscoverScreen()),
    ),

    // AI Chat Assistant (deferred, heavy AI dependency tree)
    GoRoute(
      path: '/ai-chat',
      pageBuilder: (context, state) => slideTransition(
        _DeferredLoader(
          load: ai_chat.loadLibrary(),
          builder: () => ai_chat.AiChatScreen(),
        ),
      ),
    ),

    // AI Agent (eager, lightweight action screen)
    GoRoute(
      path: '/ai-agent',
      pageBuilder: (context, state) => slideTransition(const AIAgentScreen()),
    ),

    // Note comparison diff (query params: left, right)
    GoRoute(
      path: '/notes/compare',
      pageBuilder: (context, state) => slideTransition(
        NoteCompareScreen(
          leftNoteId: state.uri.queryParameters['left']!,
          rightNoteId: state.uri.queryParameters['right']!,
        ),
      ),
    ),

    // Knowledge Graph (eager, CustomPaint-based)
    GoRoute(
      path: '/notes/graph',
      pageBuilder: (context, state) => slideTransition(const NoteGraphScreen()),
    ),

    // Properties Dashboard (eager, status/priority analytics)
    GoRoute(
      path: '/notes/dashboard',
      pageBuilder: (context, state) =>
          slideTransition(const PropertiesDashboard()),
    ),

    // Statistics & Writing Insights (eager, SQL aggregation + CustomPaint charts)
    GoRoute(
      path: '/notes/statistics',
      pageBuilder: (context, state) =>
          slideTransition(const StatisticsScreen()),
    ),

    // Daily Notes / Journal (calendar-based daily note management)
    GoRoute(
      path: '/notes/daily',
      pageBuilder: (context, state) =>
          slideTransition(const DailyNotesScreen()),
    ),

    // Reminders (list of notes with upcoming reminders)
    GoRoute(
      path: '/notes/reminders',
      pageBuilder: (context, state) => slideTransition(const RemindersScreen()),
    ),

    // Trash screen (pushed from notes screen, no bottom nav shell)
    GoRoute(
      path: '/trash',
      pageBuilder: (context, state) => slideTransition(const TrashScreen()),
    ),

    // Sync conflict resolution screen
    GoRoute(
      path: '/sync/conflicts',
      pageBuilder: (context, state) {
        final conflicts = state.extra as List<SyncConflict>? ?? [];
        return slideTransition(
          ConflictResolutionScreen(conflicts: conflicts),
        );
      },
    ),

    // Deep link route for anynote://notes/{id}.
    //
    // This route is the go_router integration point for home screen widget
    // taps and other deep link entry points that target a specific note.
    // The [DeepLinkHandler] class handles the initial URI parsing and
    // validation, then navigates to /notes/{id} for valid links or to
    // /deep-link/notes/{id} for re-validation when the note may not yet
    // be available locally (e.g. sync-in-progress scenarios).
    //
    // When the note is found, this route redirects to the standard note
    // detail screen. When not found, it redirects to the notes list with
    // an error SnackBar.
    GoRoute(
      path: '/deep-link/notes/:id',
      redirect: (context, state) {
        final noteId = state.pathParameters['id'];
        if (noteId == null || noteId.isEmpty) return '/notes';

        // Return null to let the pageBuilder render the validation screen.
        // The redirect cannot be async, so we defer the DB lookup to the
        // page widget itself.
        return null;
      },
      pageBuilder: (context, state) => slideTransition(
        _DeepLinkNoteScreen(
          noteId: state.pathParameters['id']!,
        ),
      ),
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
                final shareContent = state.uri.queryParameters['shareContent'];
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
                GoRoute(
                  path: 'diff',
                  parentNavigatorKey: rootNavigatorKey,
                  pageBuilder: (context, state) => slideTransition(
                    VersionDiffScreen(
                      noteId: state.pathParameters['id']!,
                      olderVersionId: state.uri.queryParameters['older']!,
                      newerVersionId: state.uri.queryParameters['newer']!,
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
            GoRoute(
              path: 'plan',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: plan_screen.loadLibrary(),
                  builder: () => plan_screen.PlanScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'profile',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) => slideTransition(
                _DeferredLoader(
                  load: profile_screen.loadLibrary(),
                  builder: () => profile_screen.ProfileScreen(),
                ),
              ),
            ),
            GoRoute(
              path: 'images',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const ImageManagementScreen()),
            ),
            GoRoute(
              path: 'templates',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const TemplateManagementScreen()),
            ),
            GoRoute(
              path: 'shortcuts',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const KeyboardShortcutsScreen()),
            ),
            GoRoute(
              path: 'notifications',
              parentNavigatorKey: rootNavigatorKey,
              pageBuilder: (context, state) =>
                  slideTransition(const NotificationSettingsScreen()),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: FocusTraversalOrder(
        order: const NumericFocusOrder(1),
        child: NavigationBar(
          selectedIndex: _selectedIndex(context),
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, index),
          destinations: [
            NavigationDestination(
              icon: const Icon(AppIcons.notes),
              selectedIcon: const Icon(AppIcons.notesFilled),
              label: l10n?.notesTabLabel ?? 'Notes',
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.compose),
              selectedIcon: const Icon(AppIcons.composeFilled),
              label: l10n?.composeTabLabel ?? 'Compose',
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.publish),
              selectedIcon: const Icon(AppIcons.publishFilled),
              label: l10n?.publishTabLabel ?? 'Publish',
            ),
            NavigationDestination(
              icon: const Icon(AppIcons.settings),
              selectedIcon: const Icon(AppIcons.settingsFilled),
              label: l10n?.settingsTabLabel ?? 'Settings',
            ),
          ],
        ),
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
    final notesLabel = l10n?.notesTabLabel ?? 'Notes';
    final composeLabel = l10n?.composeTabLabel ?? 'Compose';
    final publishLabel = l10n?.publishTabLabel ?? 'Publish';
    final settingsLabel = l10n?.settingsTabLabel ?? 'Settings';
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
                icon: Tooltip(
                  message: notesLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.notes),
                ),
                selectedIcon: Tooltip(
                  message: notesLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.notesFilled),
                ),
                label: Text(notesLabel),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: composeLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.compose),
                ),
                selectedIcon: Tooltip(
                  message: composeLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.composeFilled),
                ),
                label: Text(composeLabel),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: publishLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.publish),
                ),
                selectedIcon: Tooltip(
                  message: publishLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.publishFilled),
                ),
                label: Text(publishLabel),
              ),
              NavigationRailDestination(
                icon: Tooltip(
                  message: settingsLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.settings),
                ),
                selectedIcon: Tooltip(
                  message: settingsLabel,
                  preferBelow: false,
                  child: const Icon(AppIcons.settingsFilled),
                ),
                label: Text(settingsLabel),
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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.load.then((_) {
      if (mounted) setState(() => _loaded = true);
    }).catchError((_) {
      if (mounted) setState(() => _hasError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.builder();
    if (_hasError) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                AppIcons.error,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.failedToLoadDeferred ?? 'Failed to load',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  setState(() => _hasError = false);
                  widget.load.then((_) {
                    if (mounted) setState(() => _loaded = true);
                  }).catchError((_) {
                    if (mounted) setState(() => _hasError = true);
                  });
                },
                child: Text(l10n?.retry ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Intermediate screen for deep link note navigation.
///
/// Validates that the note referenced by a deep link (e.g. from a home screen
/// widget or an `anynote://notes/{id}` URL) exists in the local database.
///
/// - If the note is found and not soft-deleted, immediately redirects to
///   `/notes/{id}` (the standard note detail screen).
/// - If the note is not found, redirects to the notes list and shows an
///   error SnackBar so the user understands why the link did not work.
class _DeepLinkNoteScreen extends ConsumerStatefulWidget {
  final String noteId;

  const _DeepLinkNoteScreen({required this.noteId});

  @override
  ConsumerState<_DeepLinkNoteScreen> createState() =>
      _DeepLinkNoteScreenState();
}

class _DeepLinkNoteScreenState extends ConsumerState<_DeepLinkNoteScreen> {
  @override
  void initState() {
    super.initState();
    _validateAndNavigate();
  }

  Future<void> _validateAndNavigate() async {
    final db = ref.read(databaseProvider);
    try {
      final note = await db.notesDao.getNoteById(widget.noteId);

      if (!mounted) return;

      if (note != null && note.deletedAt == null) {
        // Note exists: navigate to the standard detail screen.
        context.go('/notes/${widget.noteId}');
      } else {
        // Note not found: redirect to notes list with error feedback.
        final l10n = AppLocalizations.of(context);
        context.go('/notes');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (messenger != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n?.noteNotFound ?? 'Note not found',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      context.go('/notes');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n?.failedToLoadNote ?? 'Failed to load note',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while the DB lookup is in progress.
    // The user will only see this briefly (typically < 100ms).
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
