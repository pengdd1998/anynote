import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final db = AppDatabase();

  // Initialize API client
  final apiClient = ApiClient(baseUrl: const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  ));

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(apiClient),
    ],
    child: const AnyNoteApp(),
  ));
}

class AnyNoteApp extends ConsumerWidget {
  const AnyNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AnyNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
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
