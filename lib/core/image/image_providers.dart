import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_cache_manager.dart';

/// Singleton LRU image cache — 80 MB budget for thumbnails.
final imageCacheManagerProvider = Provider<ImageCacheManager>((ref) {
  final manager = ImageCacheManager(maxBytes: 80 * 1024 * 1024);
  ref.onDispose(() => manager.clear());
  return manager;
});
