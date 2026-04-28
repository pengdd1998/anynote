import 'dart:convert';
import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/platform_utils.dart';
import '../../main.dart';

/// Lightweight note summary for widget display.
///
/// Contains only the data needed by native home screen widgets:
/// an identifier, display title, short preview text, and metadata.
/// No encrypted content is ever passed through this class.
class NoteSummary {
  /// Note UUID (client-generated).
  final String id;

  /// Decrypted note title (may be empty for untitled notes).
  final String title;

  /// First ~50 characters of decrypted note content for preview.
  /// Null when no content is available.
  final String? preview;

  /// Last modification timestamp (millisecond epoch).
  final DateTime updatedAt;

  /// Whether the note is pinned.
  final bool isPinned;

  NoteSummary({
    required this.id,
    required this.title,
    this.preview,
    required this.updatedAt,
    required this.isPinned,
  });

  /// Serialize to a JSON-compatible map for platform channel transfer.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'preview': preview,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'isPinned': isPinned,
      };
}

/// Service for pushing lightweight note data to native home screen widgets.
///
/// Uses platform channels to communicate with:
/// - iOS: App Group UserDefaults (group.com.anynote.app)
/// - Android: SharedPreferences via native method channel
///
/// The native widget implementations (WidgetKit on iOS, AppWidgetProvider
/// on Android) read from these shared storage locations and render the
/// note summaries on the home screen.
///
/// This service is a no-op on platforms that do not support home screen
/// widgets (web, desktop) -- all method channel calls are wrapped in
/// try-catch to handle [PlatformException].
class HomeWidgetService {
  static const _channel = MethodChannel('com.anynote.app/widget');

  /// Maximum number of characters to include in the note preview.
  static const _maxPreviewLength = 50;

  /// Update widget data with recent and pinned notes.
  ///
  /// Called whenever the note list changes (on note create/update/delete).
  /// Serializes the data to JSON and sends it to the native side via
  /// [MethodChannel]. The native implementation is responsible for
  /// writing the data to the appropriate shared storage (App Group
  /// UserDefaults on iOS, SharedPreferences on Android).
  ///
  /// Silently no-ops on platforms that do not support this method channel.
  Future<void> updateWidgetData({
    required List<NoteSummary> recentNotes,
    required List<NoteSummary> pinnedNotes,
    required int totalNoteCount,
  }) async {
    // Do not attempt platform channel calls on web or desktop.
    // Web has no concept of home screen widgets; desktop platforms
    // (Linux, macOS, Windows) do not implement this channel.
    if (kIsWeb ||
        Platform.environment.containsKey('FLUTTER_WEB') ||
        PlatformUtils.isDesktop) {
      return;
    }

    try {
      final payload = jsonEncode({
        'recentNotes': recentNotes.map((n) => n.toJson()).toList(),
        'pinnedNotes': pinnedNotes.map((n) => n.toJson()).toList(),
        'totalNoteCount': totalNoteCount,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _channel.invokeMethod<void>('updateWidgetData', {
        'payload': payload,
      });
    } on PlatformException {
      // Platform does not support home screen widgets.
      // This is expected on web, desktop, or older OS versions.
    } on MissingPluginException {
      // Method channel not registered on this platform.
    }
  }

  /// Request widget refresh on the native side.
  ///
  /// Triggers WidgetCenter.reloadAllTimelines() on iOS and
  /// AppWidgetManager.notifyAppWidgetViewDataChanged() on Android.
  /// Called after [updateWidgetData] to ensure the widget UI reflects
  /// the latest data.
  ///
  /// Silently no-ops on unsupported platforms.
  Future<void> refreshWidget() async {
    if (kIsWeb ||
        Platform.environment.containsKey('FLUTTER_WEB') ||
        PlatformUtils.isDesktop) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('refreshWidget');
    } on PlatformException {
      // Expected on unsupported platforms.
    } on MissingPluginException {
      // Method channel not registered.
    }
  }

  /// Convenience method: fetch recent and pinned notes from the database
  /// and push them to the native widget in a single call.
  ///
  /// Limits recent notes to [maxRecent] items (default 5) and pinned notes
  /// to [maxPinned] items (default 3) to keep widget data small.
  Future<void> syncToWidget({
    int maxRecent = 5,
    int maxPinned = 3,
  }) async {
    final db = globalContainer.read(databaseProvider);

    // Fetch recent non-deleted notes.
    final recentRows = await db.notesDao.getPaginatedNotes(maxRecent, 0);
    final recentSummaries = recentRows.map((note) {
      final plainContent = note.plainContent;
      return NoteSummary(
        id: note.id,
        title: note.plainTitle ?? '',
        preview: plainContent != null && plainContent.length > _maxPreviewLength
            ? plainContent.substring(0, _maxPreviewLength)
            : plainContent,
        updatedAt: note.updatedAt,
        isPinned: note.isPinned,
      );
    }).toList();

    // Fetch pinned notes separately for the pinned section.
    final allNotes = await db.notesDao.getAllNotes();
    final pinnedRows =
        allNotes.where((n) => n.isPinned).take(maxPinned).toList();
    final pinnedSummaries = pinnedRows.map((note) {
      final plainContent = note.plainContent;
      return NoteSummary(
        id: note.id,
        title: note.plainTitle ?? '',
        preview: plainContent != null && plainContent.length > _maxPreviewLength
            ? plainContent.substring(0, _maxPreviewLength)
            : plainContent,
        updatedAt: note.updatedAt,
        isPinned: true,
      );
    }).toList();

    final totalCount = await db.notesDao.countNotes();

    await updateWidgetData(
      recentNotes: recentSummaries,
      pinnedNotes: pinnedSummaries,
      totalNoteCount: totalCount,
    );
    await refreshWidget();
  }
}

/// Riverpod provider for [HomeWidgetService].
///
/// Singleton -- the service is stateless and safe to share across widgets.
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetService();
});
