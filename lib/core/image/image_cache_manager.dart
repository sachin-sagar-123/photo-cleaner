import 'dart:typed_data';

/// LRU cache for decoded thumbnail bytes.
///
/// Sits between disk I/O and the widget layer. Stores pre-decoded
/// thumbnail bytes keyed by (path, size) so repeated scrolls don't
/// re-read from disk. Evicts least-recently-used entries when the
/// byte budget is exceeded.
class ImageCacheManager {
  final int maxBytes;
  int _currentBytes = 0;

  /// Insertion-ordered map; most recently accessed entry moves to end.
  final _cache = <String, _CacheEntry>{};

  ImageCacheManager({this.maxBytes = 80 * 1024 * 1024}); // 80 MB default

  static String key(String path, int size) => '$size:$path';

  /// Returns cached bytes or null.
  Uint8List? get(String cacheKey) {
    final entry = _cache.remove(cacheKey);
    if (entry == null) return null;
    // Move to end (most recently used)
    _cache[cacheKey] = entry;
    return entry.bytes;
  }

  /// Stores bytes, evicting LRU entries if over budget.
  void put(String cacheKey, Uint8List bytes) {
    // If already cached, remove old entry first
    final existing = _cache.remove(cacheKey);
    if (existing != null) {
      _currentBytes -= existing.bytes.lengthInBytes;
    }

    _currentBytes += bytes.lengthInBytes;
    _cache[cacheKey] = _CacheEntry(bytes);

    _evict();
  }

  /// Evict entries with a specific path prefix (e.g., after photo deletion).
  void invalidatePath(String path) {
    final keysToRemove = _cache.keys.where((k) => k.contains(path)).toList();
    for (final k in keysToRemove) {
      final entry = _cache.remove(k);
      if (entry != null) _currentBytes -= entry.bytes.lengthInBytes;
    }
  }

  void clear() {
    _cache.clear();
    _currentBytes = 0;
  }

  int get currentBytes => _currentBytes;
  int get entryCount => _cache.length;

  void _evict() {
    while (_currentBytes > maxBytes && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      final entry = _cache.remove(oldest)!;
      _currentBytes -= entry.bytes.lengthInBytes;
    }
  }
}

class _CacheEntry {
  final Uint8List bytes;
  _CacheEntry(this.bytes);
}
