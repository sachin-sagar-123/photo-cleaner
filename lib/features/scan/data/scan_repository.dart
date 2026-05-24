import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/photo_asset.dart';
import 'photo_dao.dart';

/// Cached repository for photo scan data.
class ScanRepository {
  final PhotoDao _dao;
  final MemoryCache _cache;

  static const _allIdsKey = 'scan:all_ids';
  static const _ttl = Duration(minutes: 5);

  ScanRepository(this._dao, this._cache);

  Future<Result<List<String>>> getAllPhotoIds() async {
    final cached = _cache.get<List<String>>(_allIdsKey);
    if (cached != null) return Success(cached);

    try {
      final ids = await _dao.getAllPhotoIds();
      _cache.set(_allIdsKey, ids, ttl: _ttl);
      return Success(ids);
    } catch (e) {
      return Failure(DatabaseException('Failed to load photo IDs', e));
    }
  }

  Future<Result<void>> upsertPhotos(List<PhotoAsset> photos) async {
    try {
      await _dao.upsertPhotos(photos);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to save photos', e));
    }
  }

  Future<Result<void>> deletePhotos(List<String> ids) async {
    try {
      await _dao.deletePhotos(ids);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to delete photos', e));
    }
  }

  Future<Result<List<PhotoAsset>>> getPhotosByIds(List<String> ids) async {
    try {
      final photos = await _dao.getPhotosByIds(ids);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load photos', e));
    }
  }

  void invalidate() => _cache.invalidatePrefix('scan:');
}
