import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anynote/features/settings/presentation/image_management_screen.dart';
import '../../../helpers/test_app_helper.dart';

void main() {
  group('ImageManagementScreen', () {
    testWidgets('shows loading indicator while stats load', (tester) async {
      // Use a Completer that never completes so the provider stays in loading.
      final completer = Completer<ImageStorageStats>();
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) => completer.future),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows empty state when no images stored', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            return const ImageStorageStats(
              totalFiles: 0,
              totalSizeBytes: 0,
              allFiles: [],
            );
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      // Empty state text.
      expect(find.text('No images stored'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows storage overview card with formatted size',
        (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            return const ImageStorageStats(
              totalFiles: 12,
              totalSizeBytes: 3 * 1024 * 1024, // 3.0 MB
              allFiles: [],
            );
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      // Storage card should show the formatted size.
      expect(find.text('3.0 MB'), findsOneWidget);
      // Image count.
      expect(find.textContaining('12'), findsOneWidget);
      // Photo library icon.
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows cleanup and delete actions', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            return const ImageStorageStats(
              totalFiles: 5,
              totalSizeBytes: 1024,
              allFiles: [],
            );
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.byIcon(Icons.cleaning_services_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever_outlined), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows error state on failure', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            throw Exception('Failed to read directory');
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      // Error state widget should show retry button.
      expect(find.text('Retry'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('formatted size for small files', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            return const ImageStorageStats(
              totalFiles: 1,
              totalSizeBytes: 512, // 512 B
              allFiles: [],
            );
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.text('512 B'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('formatted size for KB range', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            return const ImageStorageStats(
              totalFiles: 3,
              totalSizeBytes: 1500, // ~1.5 KB
              allFiles: [],
            );
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.text('1.5 KB'), findsOneWidget);

      await handle.dispose();
    });

    testWidgets('shows app bar with correct title', (tester) async {
      final handle = await pumpScreen(
        tester,
        const ImageManagementScreen(),
        overrides: [
          ...defaultProviderOverrides(),
          imageStorageStatsProvider.overrideWith((ref) async {
            return const ImageStorageStats(
              totalFiles: 0,
              totalSizeBytes: 0,
              allFiles: [],
            );
          }),
        ],
      );
      addTearDown(() => handle.dispose());

      expect(find.text('Image Management'), findsOneWidget);

      await handle.dispose();
    });
  });
}
