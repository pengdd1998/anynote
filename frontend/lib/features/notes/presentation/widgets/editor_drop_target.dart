import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/platform/platform_utils.dart';
import '../../../../core/storage/image_storage.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// A wrapper widget that accepts dropped image files onto the editor area.
///
/// Uses the `desktop_drop` package to receive drag-and-drop events on desktop
/// platforms (macOS, Windows, Linux). On mobile and web this widget simply
/// passes through its child without any drop handling.
///
/// When image files (jpg, png, gif, webp) are dropped they are saved via
/// [ImageStorage] and an image reference is appended to the editor content.
/// Non-image files trigger a toast notification.
class EditorDropTarget extends ConsumerStatefulWidget {
  /// The editor content to wrap with drop-handling.
  final Widget child;

  /// Callback invoked with the saved local path for each accepted image.
  /// The caller is responsible for inserting the reference into the editor.
  final void Function(String localPath) onImageDropped;

  /// The note ID used to namespace saved images.
  final String noteId;

  const EditorDropTarget({
    super.key,
    required this.child,
    required this.onImageDropped,
    required this.noteId,
  });

  @override
  ConsumerState<EditorDropTarget> createState() => _EditorDropTargetState();
}

class _EditorDropTargetState extends ConsumerState<EditorDropTarget> {
  bool _isDragging = false;

  /// File extensions accepted as images.
  static const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp'};

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  Future<void> _handleDrop(List<String> paths) async {
    setState(() => _isDragging = false);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    for (final path in paths) {
      if (_isImageFile(path)) {
        try {
          final file = File(path);
          if (!await file.exists()) continue;
          final bytes = await file.readAsBytes();
          final localPath = await ImageStorage.saveImage(
            bytes,
            widget.noteId,
          );
          widget.onImageDropped(localPath);

          if (mounted) {
            AppSnackBar.info(context, message: l10n.imageAdded);
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(
              context,
              message: l10n.failedToAddImage(e.toString()),
            );
          }
        }
      } else {
        // Non-image file.
        if (mounted) {
          AppSnackBar.info(context, message: l10n.unsupportedFileType);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Drop target is only meaningful on desktop platforms with a native
    // filesystem. On mobile/web, just pass through the child.
    if (kIsWeb || !PlatformUtils.isDesktop) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) {
        setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        _handleDrop(details.files.map((f) => f.path).toList());
      },
      child: AnimatedContainer(
        duration: AppDurations.shortAnimation,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: _isDragging
              ? Border.all(
                  color: colorScheme.primary,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                )
              : null,
          color: _isDragging
              ? colorScheme.primaryContainer.withValues(alpha: 0.15)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
