import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/photo_asset.dart';
import 'drive_dao.dart';

/// Cached repository for Google Drive sync queries.
class DriveRepository {
  final DriveDao _dao;
  final MemoryCache _cache;

  static const _backedUpKey = 'drive:backed_up';
  static const _driveOnlyKey = 'drive:drive_only';
  static const _allDriveKey = 'drive:all';
  static const _duplicatesKey = 'drive:duplicates';
  static const _ttl = Duration(minutes: 5);

  DriveRepository(this._dao, this._cache);

  Future<Result<List<PhotoAsset>>> getBackedUpPhotos() async {
    final cached = _cache.get<List<PhotoAsset>>(_backedUpKey);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getBackedUpPhotos();
      _cache.set(_backedUpKey, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load backed-up photos', e));
    }
  }

  Future<Result<List<PhotoAsset>>> getDriveOnlyPhotos() async {
    final cached = _cache.get<List<PhotoAsset>>(_driveOnlyKey);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getDriveOnlyPhotos();
      _cache.set(_driveOnlyKey, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load drive-only photos', e));
    }
  }

  Future<Result<List<PhotoAsset>>> getDrivePhotos() async {
    final cached = _cache.get<List<PhotoAsset>>(_allDriveKey);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getDrivePhotos();
      _cache.set(_allDriveKey, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load drive photos', e));
    }
  }

  Future<Result<List<PhotoAsset>>> getLocalDriveDuplicates() async {
    final cached = _cache.get<List<PhotoAsset>>(_duplicatesKey);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getLocalDriveDuplicates();
      _cache.set(_duplicatesKey, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load drive duplicates', e));
    }
  }

  void invalidate() => _cache.invalidatePrefix('drive:');
}
