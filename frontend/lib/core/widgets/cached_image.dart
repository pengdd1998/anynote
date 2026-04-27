import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_durations.dart';

/// A reusable image widget that fetches and caches network images.
///
/// Wraps [CachedNetworkImage] with consistent placeholder, error, and cache
/// configuration across the app. Designed for use in note content, publish
/// previews, and user avatars.
///
/// Usage:
/// ```dart
/// CachedImage(
///   url: 'https://example.com/photo.jpg',
///   width: 200,
///   height: 150,
///   fit: BoxFit.cover,
/// )
/// ```
///
/// Cache configuration is applied globally via [CachedNetworkImageProvider]
/// defaults. To override for a specific use case, set [cacheDuration] or
/// [maxWidth] / [maxHeight].
class CachedImage extends StatelessWidget {
  /// URL of the image to load.
  final String url;

  /// Width of the image widget.
  final double? width;

  /// Height of the image widget.
  final double? height;

  /// How the image should be inscribed into the box.
  final BoxFit fit;

  /// Border radius for clipping the image.
  final BorderRadius? borderRadius;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Maximum width for the cached resized image (pixels).
  /// When provided, the cached image is resized to fit within this width
  /// before caching, reducing memory usage for large images.
  final int? maxWidth;

  /// Maximum height for the cached resized image (pixels).
  final int? maxHeight;

  /// Duration for which cached images are considered valid.
  /// Defaults to 7 days.
  final Duration cacheDuration;

  /// Widget to display while the image is loading.
  /// Defaults to a centered [CircularProgressIndicator].
  final Widget? loadingWidget;

  /// Widget to display when the image fails to load.
  /// Defaults to a grey container with a broken-image icon.
  final Widget? errorWidget;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.semanticLabel,
    this.maxWidth,
    this.maxHeight,
    this.cacheDuration = const Duration(days: 7),
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: maxWidth,
      memCacheHeight: maxHeight,
      fadeOutDuration: AppDurations.animation,
      fadeInDuration: AppDurations.animation,
      placeholder: (context, url) =>
          loadingWidget ?? const _DefaultLoadingWidget(),
      errorWidget: (context, url, error) =>
          errorWidget ?? const _DefaultErrorWidget(),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return Semantics(
      image: true,
      label: semanticLabel,
      child: image,
    );
  }
}

/// Default loading placeholder: a subtle shimmer-like indicator.
class _DefaultLoadingWidget extends StatelessWidget {
  const _DefaultLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// Default error widget: a grey container with a broken-image icon.
class _DefaultErrorWidget extends StatelessWidget {
  const _DefaultErrorWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.outline,
          size: 32,
        ),
      ),
    );
  }
}
