import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

/// Regular expression for validating identifiers (UUIDs or similar).
/// Accepts alphanumeric characters and hyphens, matching standard UUID v4
/// format like "550e8400-e29b-41d4-a716-446655440000".
final _identifierPattern = RegExp(r'^[a-zA-Z0-9-]+$');

/// Maximum allowed length for a single URI path segment.
const _maxSegmentLength = 256;

/// Handles incoming deep links for AnyNote.
///
/// Supported deep link patterns:
///   - anynote://notes/new         -> create a new note
///   - anynote://notes/{id}        -> open specific note (validates existence)
///   - anynote://share/{id}        -> open shared note
///   - anynote://share/received    -> share extension callback
///
/// For the `anynote://notes/{id}` pattern, the handler first validates the ID
/// format, then checks whether the note exists in the local database. If the
/// note is not found (e.g. it was deleted or never synced to this device), the
/// user is redirected to the notes list with an error SnackBar.
class DeepLinkHandler {
  /// Validates a URI path segment.
  ///
  /// Returns `true` if the segment is safe to use in navigation, `false`
  /// otherwise. A segment is considered invalid if it is:
  ///   - empty
  ///   - longer than [_maxSegmentLength] characters
  ///   - contains path traversal patterns (".." or "/")
  ///   - contains characters outside the allowed set
  static bool _isValidSegment(String segment) {
    if (segment.isEmpty) {
      debugPrint('DeepLinkHandler: rejected empty segment');
      return false;
    }
    if (segment.length > _maxSegmentLength) {
      debugPrint(
        'DeepLinkHandler: rejected overly long segment '
        '(${segment.length} chars)',
      );
      return false;
    }
    if (segment.contains('..') || segment.contains('/')) {
      debugPrint('DeepLinkHandler: rejected segment with traversal pattern');
      return false;
    }
    if (!_identifierPattern.hasMatch(segment)) {
      debugPrint('DeepLinkHandler: rejected segment with invalid characters');
      return false;
    }
    return true;
  }

  /// Validates that a segment looks like a note or share identifier.
  ///
  /// Enforces a stricter format: lowercase hex digits and hyphens only,
  /// which covers standard UUID v4 identifiers used throughout the app.
  static bool _isValidId(String segment) {
    if (!_isValidSegment(segment)) return false;
    // UUID v4 format: 8-4-4-4-12 hex characters (with or without hyphens),
    // or a plain alphanumeric ID. Allow lowercase hex and hyphens.
    final uuidPattern = RegExp(r'^[a-f0-9-]+$');
    if (!uuidPattern.hasMatch(segment)) {
      debugPrint('DeepLinkHandler: rejected identifier with invalid chars');
      return false;
    }
    return true;
  }

  /// Process a deep link URI and navigate to the appropriate screen.
  ///
  /// All URI segments are validated before being used in navigation paths.
  /// Invalid or malformed URIs are rejected with a debug log warning and no
  /// navigation occurs.
  ///
  /// For note deep links (`anynote://notes/{id}`), the note's existence is
  /// verified against the local database before navigation. If the note does
  /// not exist, the user lands on the notes list with an error SnackBar.
  static void handleUri(BuildContext context, Uri uri) {
    // Deep link URIs like "anynote://notes/new" are parsed by Dart's URI
    // parser with "notes" as the host and "new" as the first path segment.
    // Account for this by combining the host (if non-empty) with the path
    // segments into a unified segment list.
    final rawSegments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ];
    if (rawSegments.isEmpty) return;

    // Validate the first segment (the route namespace) before switching on it.
    if (!_isValidSegment(rawSegments[0])) return;

    switch (rawSegments[0]) {
      case 'notes':
        if (rawSegments.length == 1 ||
            (rawSegments.length == 2 && rawSegments[1] == 'new')) {
          context.push('/notes/new');
        } else if (rawSegments.length == 2) {
          if (!_isValidId(rawSegments[1])) return;
          _handleNoteDeepLink(context, rawSegments[1]);
        }
        break;
      case 'share':
        if (rawSegments.length == 2) {
          if (rawSegments[1] == 'received') {
            // Share extension callback: navigate to the share receiver
            // route which will redirect to the note editor.
            context.push('/share/received');
          } else {
            if (!_isValidId(rawSegments[1])) return;
            context.push('/share/${rawSegments[1]}');
          }
        }
        break;
    }
  }

  /// Handle an `anynote://notes/{id}` deep link by validating the note exists.
  ///
  /// Checks the local database for the given [noteId]. If found, navigates
  /// directly to the note detail screen. If not found (deleted, never synced,
  /// or invalid), redirects to the notes list and shows an error SnackBar.
  ///
  /// Falls back to direct navigation when the database provider is not
  /// available (e.g. during testing or before the full app initializes).
  static void _handleNoteDeepLink(BuildContext context, String noteId) {
    // Perform the database lookup asynchronously, then navigate on the next
    // frame so that the BuildContext is still valid.
    () async {
      // Try to access the database. If globalContainer is not initialized
      // (test environment, early lifecycle), fall back to direct navigation.
      // The note detail screen itself handles the "not found" case.
      AppDatabase? db;
      try {
        db = globalContainer.read(databaseProvider);
      } catch (e) {
        // globalContainer not initialized or databaseProvider not overridden.
        // Fall through to direct navigation.
        debugPrint('[DeepLinkHandler] database provider not available: $e');
      }

      if (db == null) {
        // No database available: navigate directly and let the detail screen
        // handle missing notes (it shows "Note not found" via FutureBuilder).
        if (context.mounted) context.push('/notes/$noteId');
        return;
      }

      final note = await db.notesDao.getNoteById(noteId);

      if (!context.mounted) return;

      if (note != null && note.deletedAt == null) {
        // Note exists and is not soft-deleted: navigate to detail screen.
        context.push('/notes/$noteId');
      } else {
        // Note not found or deleted: go to notes list and show error.
        final l10n = AppLocalizations.of(context);
        context.go('/notes');
        // Post-frame callback ensures the Scaffold is mounted before showing
        // the SnackBar, since context.go rebuilds the widget tree.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
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
    }();
  }
}
