import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'core/database/app_database.dart';
import 'core/deep_link/deep_link_handler.dart';
import 'core/locale/locale_provider.dart';
import 'core/monitoring/error_reporter.dart';
import 'l10n/app_localizations.dart';
import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/sync/sync_lifecycle.dart';
import 'core/error/connectivity_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/keyboard_shortcuts.dart';
import 'routing/app_router.dart';

/// Global reference to the Riverpod container so that non-widget code
/// (e.g. GoRouter redirect) can read providers.
late final ProviderContainer globalContainer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize error reporting before anything else.
  ErrorReporter().init();

  // Initialize database
  final db = AppDatabase();

  // Initialize API client
  final apiClient = ApiClient(baseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  ));

  // Load any previously-stored tokens so the auth interceptor has them
  // available on the very first request.
  apiClient.loadStoredTokens();

  runZonedGuarded(() {
    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
      ],
      child: const AnyNoteApp(),
    ));
  }, (error, stackTrace) {
    ErrorReporter().reportError(error, stackTrace, context: 'unhandled');
  });
}

class AnyNoteApp extends ConsumerStatefulWidget {
  const AnyNoteApp({super.key});

  @override
  ConsumerState<AnyNoteApp> createState() => _AnyNoteAppState();
}

class _AnyNoteAppState extends ConsumerState<AnyNoteApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Store the container globally so the router redirect can access it.
    // We use Future.microtask to ensure the ProviderScope is fully built.
    Future.microtask(() {
      if (mounted) {
        globalContainer = ProviderScope.containerOf(context);
        // If tokens were previously stored, mark the user as authenticated
        // so the router redirect does not kick them back to login.
        final api = globalContainer.read(apiClientProvider);
        if (api.accessToken != null) {
          globalContainer.read(authStateProvider.notifier).state = true;
        }
        // Initialize sync lifecycle (auto-starts periodic sync if authed).
        // Also attempts to unlock crypto from stored keys.
        globalContainer.read(syncLifecycleProvider);
        // Initialize connectivity-aware sync trigger so that queued
        // offline operations are flushed when connectivity is restored.
        globalContainer.read(connectivitySyncTriggerProvider);
        // Initialize push notifications (graceful no-op if Firebase is
        // not configured). Only init after auth is confirmed.
        if (globalContainer.read(authStateProvider)) {
          globalContainer.read(pushNotificationServiceProvider).init();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op placeholder for lifecycle changes.
  }

  @override
  Future<bool> didPushRouteInformation(
      RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    if (uri.scheme == 'anynote') {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        DeepLinkHandler.handleUri(context, uri);
        return true;
      }
    }
    return super.didPushRouteInformation(routeInformation);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    return AppShortcuts(
      child: MaterialApp.router(
        title: 'AnyNote',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
      ),
    );
  }
}

// ── Global Providers ────────────────────────────────

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Database provider must be overridden');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('API client provider must be overridden');
});

/// Tracks whether the user is currently authenticated.
/// Set to true after successful login/register, false on logout.
final authStateProvider = StateProvider<bool>((ref) => false);

/// Whether the onboarding screen has been shown before.
/// Stored in flutter_secure_storage so it survives app reinstalls on
/// devices with secure enclave but is not backed up to the cloud.
///
/// Uses a FutureProvider internally but caches the result in a synchronous
/// StateProvider so that the GoRouter redirect (which must be synchronous)
/// can read it without waiting for the future to complete.
final _hasSeenOnboardingFutureProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  return (await storage.read(key: 'has_seen_onboarding')) == 'true';
});

/// Synchronous provider: true once onboarding has been completed.
/// Defaults to false (show onboarding) until the async read resolves.
final hasSeenOnboardingProvider = StateProvider<bool>((ref) {
  // Kick off the async read.
  final asyncValue = ref.watch(_hasSeenOnboardingFutureProvider);
  // Extract the value synchronously if available.
  if (asyncValue is AsyncData<bool>) {
    return asyncValue.value;
  }
  return false;
});
