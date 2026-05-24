import 'package:flutter/material.dart';

import 'image_cache_manager.dart';
import 'thumbnail_provider.dart';

/// Displays a photo with progressive loading: low-res thumbnail first,
/// then full resolution crossfading in when decoded.
///
/// Use in detail/preview screens where the user expects to see a sharp
/// image after a brief placeholder.
class ProgressiveImage extends StatefulWidget {
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
  State<ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<ProgressiveImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _fullResLoaded = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetFull = widget.fullSize ?? (screenWidth * 2).toInt();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Low-res thumbnail (always present as base layer)
        Image(
          image: ThumbnailProvider(
            path: widget.path,
            size: widget.thumbnailSize,
            cacheManager: widget.cacheManager,
          ),
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              widget.errorWidget ?? _defaultError(),
        ),

        // Full-res image crossfades in when decoded
        FadeTransition(
          opacity: _fadeController,
          child: Image(
            image: ThumbnailProvider(
              path: widget.path,
              size: targetFull,
              cacheManager: widget.cacheManager,
            ),
            fit: widget.fit,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                // Already in cache — show immediately, no animation needed
                if (!_fullResLoaded) {
                  _fullResLoaded = true;
                  _fadeController.value = 1.0;
                }
                return child;
              }
              if (frame != null && !_fullResLoaded) {
                _fullResLoaded = true;
                _fadeController.forward();
              }
              return child;
            },
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
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
