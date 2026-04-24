import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'core/crypto/web_crypto_compat.dart';
import 'core/database/app_database.dart';
import 'core/deep_link/deep_link_handler.dart';
import 'core/locale/locale_provider.dart';
import 'core/monitoring/error_reporter.dart';
import 'l10n/app_localizations.dart';
import 'core/network/api_client.dart';
import 'core/notifications/push_service.dart';
import 'core/platform/platform_utils.dart';
import 'core/share/receive_share_service.dart';
import 'core/storage/window_state.dart';
import 'core/sync/sync_lifecycle.dart';
import 'core/sync/background_sync_service.dart';
import 'core/error/connectivity_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/animation_config.dart';
import 'core/widgets/app_menu_bar.dart';
import 'core/widgets/keyboard_shortcuts.dart';
import 'routing/app_router.dart';

/// Global reference to the Riverpod container so that non-widget code
/// (e.g. GoRouter redirect) can read providers.
late final ProviderContainer globalContainer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize error reporting before anything else.
  ErrorReporter.instance.init();

  // Initialize crypto backend (no-op on web where WebCrypto is available;
  // on native, sodium_libs is initialized lazily by Encryptor/MasterKeyManager).
  try {
    await CryptoCompat.init();
  } catch (e, st) {
    ErrorReporter.instance.reportError(e, st, context: 'crypto_init');
    // Continue — crypto will be initialized lazily when first needed.
  }

  // Initialize window_manager on desktop and restore saved bounds.
  if (PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();
    final savedBounds = await WindowStateService.load();
    if (savedBounds != null) {
      await windowManager.setSize(Size(savedBounds.width, savedBounds.height));
      await windowManager.setPosition(Offset(savedBounds.x, savedBounds.y));
      if (savedBounds.isMaximized) {
        await windowManager.maximize();
      }
    } else {
      const defaults = WindowBounds.defaults;
      await windowManager.setSize(Size(defaults.width, defaults.height));
      await windowManager.setPosition(Offset(defaults.x, defaults.y));
    }
    await windowManager.show();
  }

  // Initialize database. Wrapping in try-catch to report migration failures
  // without crashing the app — the user sees the error in logs/reporting.
  final db = AppDatabase();
  try {
    await db.customSelect('SELECT 1').getSingle();
  } catch (e, st) {
    ErrorReporter.instance.reportError(e, st, context: 'database_init');
  }

  // Initialize API client
  final apiClient = ApiClient(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
  );

  // Load any previously-stored tokens so the auth interceptor has them
  // available on the very first request.
  apiClient.loadStoredTokens();

  runZonedGuarded(() {
    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(apiClient),
        ],
        child: const AnyNoteApp(),
      ),
    );
  }, (error, stackTrace) {
    ErrorReporter.instance.reportError(error, stackTrace, context: 'unhandled');
  });
}

class AnyNoteApp extends ConsumerStatefulWidget {
  const AnyNoteApp({super.key});

  @override
  ConsumerState<AnyNoteApp> createState() => _AnyNoteAppState();
}

class _AnyNoteAppState extends ConsumerState<AnyNoteApp>
    with WidgetsBindingObserver, WindowListener {
  StreamSubscription<SharedContent>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformUtils.isDesktop) {
      windowManager.addListener(this);
    }
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
        // Initialize background sync (WorkManager on Android, BGTaskScheduler
        // on iOS). Re-registers the periodic task if the user had enabled it.
        BackgroundSyncService.initialize();
        // Initialize push notifications (graceful no-op if Firebase is
        // not configured). Only init after auth is confirmed.
        if (globalContainer.read(authStateProvider)) {
          globalContainer.read(pushNotificationServiceProvider).init();
        }
        // Initialize share extension receiver so that shared content
        // arriving during cold start is detected.
        final shareService = globalContainer.read(receiveShareServiceProvider);
        shareService.init();

        // Listen for incoming shares and navigate to the note editor.
        _shareSubscription = shareService.onShareReceived.listen((content) {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null && navContext.mounted) {
            final encoded = Uri.encodeComponent(content.toNoteContent());
            navContext.push('/notes/new?shareContent=$encoded');
            shareService.markConsumed();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    if (PlatformUtils.isDesktop) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app resumes from background, check for any pending share
    // data that may have arrived from the share extension while the app
    // was suspended (especially relevant on iOS).
    if (state == AppLifecycleState.resumed) {
      globalContainer.read(receiveShareServiceProvider).checkPendingShare();
    }
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
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

  // ── WindowListener callbacks (desktop only) ─────────

  @override
  void onWindowMoved() => _saveWindowBounds();

  @override
  void onWindowResized() => _saveWindowBounds();

  @override
  void onWindowClose() async {
    // Persist window bounds before closing.
    await _saveWindowBounds();
    await windowManager.destroy();
  }

  /// Persist current window position and size.
  Future<void> _saveWindowBounds() async {
    if (!PlatformUtils.isDesktop) return;
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      final isMaximized = await windowManager.isMaximized();
      await WindowStateService.save(
        x: pos.dx,
        y: pos.dy,
        width: size.width,
        height: size.height,
        isMaximized: isMaximized,
      );
    } catch (_) {
      // Failed to save window bounds -- non-critical.
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeOption = ref.watch(themeOptionProvider);

    return AppKeyboardShortcuts(
      child: AnimationConfigInjector(
        child: AppMenuBar(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.8,
            maxScaleFactor: 2.0,
            child: MaterialApp.router(
              title: 'AnyNote',
              debugShowCheckedModeBanner: false,
              showSemanticsDebugger: false,
              theme: selectThemeData(
                      themeOption, MediaQuery.platformBrightnessOf(context)) ??
                  AppTheme.lightTheme(),
              darkTheme: AppTheme.darkTheme(),
              highContrastTheme: AppTheme.highContrastLightTheme(),
              highContrastDarkTheme: AppTheme.highContrastDarkTheme(),
              themeMode: selectThemeMode(themeOption),
              routerConfig: appRouter,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
            ),
          ),
        ),
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

/// Global [ErrorReporter] singleton as a Riverpod provider so that
/// screens and other providers can access it through the widget tree.
final errorReporterProvider = Provider<ErrorReporter>((ref) {
  return ErrorReporter.instance;
});

/// Whether the onboarding screen has been shown before.
/// Stored in flutter_secure_storage so it survives app reinstalls on
/// devices with secure enclave but is not backed up to the cloud.
///
/// Uses a FutureProvider internally but caches the result in a synchronous
/// StateProvider so that the GoRouter redirect (which must be synchronous)
/// can read it without waiting for the future to complete.
final _hasSeenOnboardingFutureProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }
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
