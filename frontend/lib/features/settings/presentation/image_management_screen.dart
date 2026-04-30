import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show databaseProvider;

// ---------------------------------------------------------------------------
// Provider: image storage statistics
// ---------------------------------------------------------------------------

/// Holds computed image storage stats.
class ImageStorageStats {
  final int totalFiles;
  final int totalSizeBytes;
  final List<File> allFiles;

  const ImageStorageStats({
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.allFiles,
  });

  String get formattedSize => _formatBytes(totalSizeBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Scans the note_images directory and returns statistics.
Future<ImageStorageStats> _computeStats() async {
  if (kIsWeb) {
    return const ImageStorageStats(
      totalFiles: 0,
      totalSizeBytes: 0,
      allFiles: [],
    );
  }
  final appDir = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(appDir.path, 'note_images'));
  if (!await dir.exists()) {
    return const ImageStorageStats(
      totalFiles: 0,
      totalSizeBytes: 0,
      allFiles: [],
    );
  }

  int totalSize = 0;
  final files = <File>[];
  await for (final entity in dir.list()) {
    if (entity is File) {
      try {
        totalSize += await entity.length();
        files.add(entity);
      } catch (e) {
        // Skip files that cannot be read.
        debugPrint('[ImageManagementScreen] skipped unreadable file: $e');
      }
    }
  }
  return ImageStorageStats(
    totalFiles: files.length,
    totalSizeBytes: totalSize,
    allFiles: files,
  );
}

/// Provider that computes image storage statistics on demand.
final imageStorageStatsProvider =
    FutureProvider.autoDispose<ImageStorageStats>((ref) async {
  return _computeStats();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Settings screen for managing local image storage.
///
/// Displays:
/// - Total storage used and image count
/// - List of orphaned images (images whose note has been deleted)
/// - Actions to clean up orphaned images or delete all images
class ImageManagementScreen extends ConsumerWidget {
  const ImageManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(imageStorageStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.imageManagement)),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: '$e',
          onRetry: () => ref.invalidate(imageStorageStatsProvider),
        ),
        data: (stats) => _buildContent(context, ref, stats, l10n),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ImageStorageStats stats,
    AppLocalizations l10n,
  ) {
    if (kIsWeb) {
      return Center(
        child: Text(l10n.notSupportedOnWeb),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 16),

        // -- Storage overview card ------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        AppIcons.photoLibrary,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.totalStorage,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    stats.formattedSize,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.imageCount(stats.totalFiles),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // -- Actions --------------------------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(AppIcons.cleaningServices),
                  title: Text(l10n.cleanupOrphaned),
                  subtitle: Text(
                    l10n.orphanedImages,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _cleanupOrphaned(context, ref, stats, l10n),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(
                    AppIcons.deleteForeverOutline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.deleteAllImages,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => _deleteAll(context, ref, stats, l10n),
                ),
              ],
            ),
          ),
        ),

        // -- Empty state ----------------------------------------------------
        if (stats.totalFiles == 0)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(child: Text(l10n.noImagesStored)),
          ),
      ],
    );
  }

  /// Identify and delete orphaned images (images whose note no longer exists).
  ///
  /// Image filenames follow the pattern `{noteId}_{hash}.png`. We extract
  /// the noteId prefix and check whether any note in the database has that ID.
  Future<void> _cleanupOrphaned(
    BuildContext context,
    WidgetRef ref,
    ImageStorageStats stats,
    AppLocalizations l10n,
  ) async {
    if (stats.allFiles.isEmpty) return;

    // Collect all note IDs from the database.
    final db = ref.read(databaseProvider);
    final allNotes = await db.notesDao.getAllNotes();
    final noteIds = allNotes.map((n) => n.id).toSet();

    int deletedCount = 0;
    for (final file in stats.allFiles) {
      final basename = p.basename(file.path);
      // Filename pattern: {noteId}_{hash}.png
      final underscoreIndex = basename.indexOf('_');
      if (underscoreIndex < 0) continue;
      final noteId = basename.substring(0, underscoreIndex);

      if (!noteIds.contains(noteId)) {
        try {
          await file.delete();
          deletedCount++;
        } catch (e) {
          // Skip files that cannot be deleted.
          debugPrint(
            '[ImageManagementScreen] failed to delete orphaned file: $e',
          );
        }
      }
    }

    if (!context.mounted) return;
    AppSnackBar.info(context, message: l10n.cleanupComplete(deletedCount));
    ref.invalidate(imageStorageStatsProvider);
  }

  /// Delete all stored images after user confirmation.
  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    ImageStorageStats stats,
    AppLocalizations l10n,
  ) async {
    if (stats.allFiles.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAllImages),
        content: Text(l10n.deleteAllImagesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    for (final file in stats.allFiles) {
      try {
        await file.delete();
      } catch (e) {
        // Skip files that cannot be deleted.
        debugPrint('[ImageManagementScreen] failed to delete file: $e');
      }
    }

    if (!context.mounted) return;
    AppSnackBar.info(context, message: l10n.imageDeleted);
    ref.invalidate(imageStorageStatsProvider);
  }
}
