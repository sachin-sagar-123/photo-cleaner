import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/photo_asset.dart';
import 'browser_dao.dart';

/// Cached repository for photo browser (unreviewed photos).
class BrowserRepository {
  final BrowserDao _dao;
  final MemoryCache _cache;

  static const _listKey = 'browser:unreviewed';
  static const _ttl = Duration(minutes: 3);

  BrowserRepository(this._dao, this._cache);

  Future<Result<List<PhotoAsset>>> getUnreviewedPhotos() async {
    final cached = _cache.get<List<PhotoAsset>>(_listKey);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getUnreviewedPhotos();
      _cache.set(_listKey, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load unreviewed photos', e));
    }
  }

  Future<Result<void>> markReviewed(String id, {bool reviewed = true}) async {
    try {
      await _dao.markReviewed(id, reviewed: reviewed);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to mark reviewed', e));
    }
  }

  Future<Result<void>> markAllReviewed(List<String> ids, {bool reviewed = true}) async {
    try {
      await _dao.markAllReviewed(ids, reviewed: reviewed);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to batch mark reviewed', e));
    }
  }

  void invalidate() => _cache.invalidatePrefix('browser:');
}
