import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
///   - anynote://notes/{id}        -> open specific note
///   - anynote://share/{id}        -> open shared note
///   - anynote://share/received    -> share extension callback
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
          context.push('/notes/${rawSegments[1]}');
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
}
