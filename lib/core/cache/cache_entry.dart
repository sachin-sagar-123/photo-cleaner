/// A cached value with TTL expiration.
class CacheEntry<T> {
  final T value;
  final DateTime cachedAt;
  final Duration ttl;

  CacheEntry(this.value, {this.ttl = const Duration(minutes: 5)})
      : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// In-memory cache with TTL and key-based invalidation.
class MemoryCache {
  final Map<String, CacheEntry<dynamic>> _store = {};

  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void set<T>(String key, T value, {Duration ttl = const Duration(minutes: 5)}) {
    _store[key] = CacheEntry<T>(value, ttl: ttl);
  }

  void invalidate(String key) => _store.remove(key);

  /// Invalidate all keys matching a prefix.
  void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() => _store.clear();

  int get size => _store.length;
}
