import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/models.dart';
import 'dashboard_dao.dart';

/// Cached repository for dashboard data.
/// Aggregates are expensive SQL queries — cache for 2 minutes.
class DashboardRepository {
  final DashboardDao _dao;
  final MemoryCache _cache;

  static const _statsKey = 'dashboard:stats';
  static const _unreviewedKey = 'dashboard:unreviewed';
  static const _importantKey = 'dashboard:important';
  static const _ttl = Duration(minutes: 2);

  DashboardRepository(this._dao, this._cache);

  Future<Result<StorageStats>> getStorageStats() async {
    final cached = _cache.get<StorageStats>(_statsKey);
    if (cached != null) return Success(cached);

    try {
      final agg = await _dao.getStorageAggregates();
      const totalBytes = 68719476736; // 64 GB
      final stats = StorageStats(
        totalBytes: totalBytes,
        usedBytes: agg['total_bytes']!,
        photoBytes: agg['total_bytes']!,
        duplicateBytes: agg['duplicate_bytes']!,
        junkBytes: agg['junk_bytes']!,
        backedUpBytes: agg['backed_up_bytes']!,
        totalPhotos: agg['total_photos']!,
        duplicateCount: agg['duplicate_count']!,
        junkCount: agg['junk_count']!,
      );
      _cache.set(_statsKey, stats, ttl: _ttl);
      return Success(stats);
    } catch (e) {
      return Failure(DatabaseException('Failed to load stats: $e', e));
    }
  }

  Future<Result<int>> getUnreviewedCount() async {
    final cached = _cache.get<int>(_unreviewedKey);
    if (cached != null) return Success(cached);

    try {
      final count = await _dao.getUnreviewedCount();
      _cache.set(_unreviewedKey, count, ttl: _ttl);
      return Success(count);
    } catch (e) {
      return Failure(DatabaseException('Failed to load unreviewed count', e));
    }
  }

  Future<Result<int>> getImportantCount() async {
    final cached = _cache.get<int>(_importantKey);
    if (cached != null) return Success(cached);

    try {
      final count = await _dao.getImportantCount();
      _cache.set(_importantKey, count, ttl: _ttl);
      return Success(count);
    } catch (e) {
      return Failure(DatabaseException('Failed to load important count', e));
    }
  }

  Future<Result<int>> getCategoryCount(PhotoCategory cat) async {
    final key = 'dashboard:cat:${cat.index}';
    final cached = _cache.get<int>(key);
    if (cached != null) return Success(cached);

    try {
      final count = await _dao.getPhotosCountByCategory(cat);
      _cache.set(key, count, ttl: _ttl);
      return Success(count);
    } catch (e) {
      return Failure(DatabaseException('Failed to load category count', e));
    }
  }

  /// Invalidate all dashboard caches — call after scan, delete, import.
  void invalidate() => _cache.invalidatePrefix('dashboard:');
}
