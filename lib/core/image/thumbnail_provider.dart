import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'image_cache_manager.dart';

/// Custom [ImageProvider] that loads file-based thumbnails through
/// [ImageCacheManager] with decode-time downsampling.
///
/// Advantages over raw `Image.file(cacheWidth:)`:
/// - LRU byte cache survives widget rebuilds and scroll-off
/// - Isolate-based decode doesn't block the UI thread
/// - Consistent cache key format across the app
class ThumbnailProvider extends ImageProvider<ThumbnailProvider> {
  final String path;
  final int size;
  final ImageCacheManager cacheManager;

  const ThumbnailProvider({
    required this.path,
    required this.size,
    required this.cacheManager,
  });

  @override
  Future<ThumbnailProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
      ThumbnailProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Path', path),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
      ThumbnailProvider key, ImageDecoderCallback decode) async {
    final cacheKey = ImageCacheManager.key(path, size);

    // Check LRU cache first
    final cached = cacheManager.get(cacheKey);
    if (cached != null) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(cached);
      return decode(buffer,
          getTargetSize: (w, h) => _targetSize(w, h, size));
    }

    // Read from disk (async to avoid blocking UI thread)
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('File not found: $path');
    }

    final bytes = await file.readAsBytes();

    // Store raw bytes in LRU cache for fast re-decode
    cacheManager.put(cacheKey, bytes);

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer,
        getTargetSize: (w, h) => _targetSize(w, h, size));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThumbnailProvider &&
        other.path == path &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(path, size);

  @override
  String toString() => 'ThumbnailProvider($path, ${size}px)';

  /// Scale down to fit within [maxDim] while preserving aspect ratio.
  static ui.TargetImageSize _targetSize(int width, int height, int maxDim) {
    if (width <= maxDim && height <= maxDim) {
      return ui.TargetImageSize(width: width, height: height);
    }
    final scale = maxDim / (width > height ? width : height);
    return ui.TargetImageSize(
      width: (width * scale).round(),
      height: (height * scale).round(),
    );
  }
}
