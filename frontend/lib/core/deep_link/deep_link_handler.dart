import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handles incoming deep links for AnyNote.
///
/// Supported deep link patterns:
///   - anynote://notes/new     -> create a new note
///   - anynote://notes/{id}    -> open specific note
///   - anynote://share/{id}    -> open shared note
class DeepLinkHandler {
  /// Process a deep link URI and navigate to the appropriate screen.
  static void handleUri(BuildContext context, Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;

    switch (segments[0]) {
      case 'notes':
        if (segments.length == 1 ||
            (segments.length == 2 && segments[1] == 'new')) {
          context.push('/notes/new');
        } else if (segments.length == 2) {
          context.push('/notes/${segments[1]}');
        }
        break;
      case 'share':
        if (segments.length == 2) {
          context.push('/share/${segments[1]}');
        }
        break;
    }
  }
}
