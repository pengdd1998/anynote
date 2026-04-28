import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../../../core/constants/app_durations.dart';
import '../../../../l10n/app_localizations.dart';

/// Full-screen image gallery viewer with pinch-to-zoom and swipe navigation.
///
/// Opens as a full-screen dialog with a black background. Supports:
/// - Pinch-to-zoom via [InteractiveViewer]
/// - Swipe between images via [PageView]
/// - Close button in top-right corner
/// - Image counter in top-left corner
/// - Share button to share the image file via system share sheet
/// - Delete button to remove the image from storage
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   PageRouteBuilder(
///     opaque: false,
///     pageBuilder: (_, __, ___) => ImageGalleryViewer(
///       imagePaths: paths,
///       initialIndex: 0,
///       onDelete: (index) async { ... },
///     ),
///   ),
/// );
/// ```
class ImageGalleryViewer extends StatefulWidget {
  /// Local file paths of images to display.
  final List<String> imagePaths;

  /// Index of the image to show initially.
  final int initialIndex;

  /// Called when the user confirms deletion of the image at [index].
  /// The viewer removes the image from its local list after this callback.
  final Future<void> Function(int index)? onDelete;

  const ImageGalleryViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.onDelete,
  });

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;

  /// Mutable copy so we can remove deleted items without affecting the caller.
  late List<String> _paths;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _paths = List<String>.from(widget.imagePaths);
    _currentIndex = widget.initialIndex.clamp(0, _paths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _animController = AnimationController(
      vsync: this,
      duration: AppDurations.mediumAnimation,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _close() {
    _animController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _shareImage(int index) async {
    if (kIsWeb || index < 0 || index >= _paths.length) return;
    final file = File(_paths[index]);
    if (!await file.exists()) return;
    await Share.shareXFiles(
      [XFile(_paths[index])],
      sharePositionOrigin: Rect.fromPoints(
        Offset.zero,
        const Offset(100, 100),
      ),
    );
  }

  Future<void> _deleteImage(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteImage),
        content: Text(l10n.deleteImageConfirm),
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

    if (confirmed != true || !mounted) return;

    if (widget.onDelete != null) {
      await widget.onDelete!(index);
    }

    setState(() {
      _paths.removeAt(index);
      if (_paths.isEmpty) {
        _close();
        return;
      }
      if (_currentIndex >= _paths.length) {
        _currentIndex = _paths.length - 1;
      }
    });

    // Rebuild the page controller for the new list length.
    _pageController.dispose();
    _pageController = PageController(initialPage: _currentIndex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_paths.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.close,
              onPressed: _close,
            ),
            title: Text(
              '${_currentIndex + 1}/${_paths.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            centerTitle: false,
            actions: [
              if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: l10n.shareImage,
                  onPressed: () => _shareImage(_currentIndex),
                ),
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.deleteImage,
                  onPressed: () => _deleteImage(_currentIndex),
                ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: _paths.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _ZoomableImage(path: _paths[index]);
            },
          ),
        ),
      ),
    );
  }
}

/// A single zoomable image using [InteractiveViewer].
class _ZoomableImage extends StatefulWidget {
  final String path;

  const _ZoomableImage({required this.path});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: kIsWeb
            ? const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              )
            : Image.file(
                File(widget.path),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
      ),
    );
  }
}
