import 'dart:io';

import 'package:flutter/material.dart';

import 'image_cache_manager.dart';
import 'thumbnail_provider.dart';

/// Displays a photo with progressive loading: low-res thumbnail first,
/// then full resolution on demand.
///
/// Use in detail/preview screens where the user expects to see a sharp
/// image after a brief placeholder.
class ProgressiveImage extends StatelessWidget {
  final String path;
  final ImageCacheManager cacheManager;
  final BoxFit fit;
  final int thumbnailSize;
  final int? fullSize;
  final Widget? errorWidget;

  const ProgressiveImage({
    super.key,
    required this.path,
    required this.cacheManager,
    this.fit = BoxFit.cover,
    this.thumbnailSize = 200,
    this.fullSize,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (!File(path).existsSync()) {
      return errorWidget ?? _defaultError();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final targetFull = fullSize ?? (screenWidth * 2).toInt();

    return Image(
      image: ThumbnailProvider(
        path: path,
        size: targetFull,
        cacheManager: cacheManager,
      ),
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        // Show low-res thumbnail while full-res loads
        return Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: ThumbnailProvider(
                path: path,
                size: thumbnailSize,
                cacheManager: cacheManager,
              ),
              fit: fit,
            ),
            AnimatedOpacity(
              opacity: frame != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (_, __, ___) => errorWidget ?? _defaultError(),
    );
  }

  Widget _defaultError() => Container(
        color: Colors.grey[900],
        child: const Icon(Icons.broken_image, color: Colors.white38, size: 32),
      );
}

/// Optimized grid thumbnail widget. Uses [ThumbnailProvider] with
/// the LRU cache for smooth scrolling through thousands of photos.
class CachedThumbnail extends StatelessWidget {
  final String path;
  final ImageCacheManager cacheManager;
  final int size;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorWidget;

  const CachedThumbnail({
    super.key,
    required this.path,
    required this.cacheManager,
    this.size = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: ThumbnailProvider(
        path: path,
        size: size,
        cacheManager: cacheManager,
      ),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          errorWidget ??
          Container(
            color: Colors.grey[900],
            child: const Icon(Icons.broken_image,
                color: Colors.white38, size: 24),
          ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
