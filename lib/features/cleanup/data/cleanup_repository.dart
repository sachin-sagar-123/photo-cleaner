import 'dart:io';

import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/models.dart';
import 'cleanup_dao.dart';

/// Cached repository for cleanup operations.
class CleanupRepository {
  final CleanupDao _dao;
  final MemoryCache _cache;

  static const _ttl = Duration(minutes: 3);

  CleanupRepository(this._dao, this._cache);

  Future<Result<List<PhotoAsset>>> getJunkPhotos() async {
    const key = 'cleanup:junk';
    final cached = _cache.get<List<PhotoAsset>>(key);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getPhotosByIssue(QualityIssue.junk);
      _cache.set(key, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load junk photos', e));
    }
  }

  Future<Result<List<PhotoAsset>>> getBlurryPhotos() async {
    const key = 'cleanup:blurry';
    final cached = _cache.get<List<PhotoAsset>>(key);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getPhotosByIssue(QualityIssue.blurry);
      _cache.set(key, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load blurry photos', e));
    }
  }

  Future<Result<List<PhotoAsset>>> getBackedUpPhotos() async {
    const key = 'cleanup:backed_up';
    final cached = _cache.get<List<PhotoAsset>>(key);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getBackedUpPhotosForCleanup();
      _cache.set(key, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load backed up photos', e));
    }
  }

  Future<Result<void>> deletePhotos(List<PhotoAsset> photos) async {
    try {
      // Delete files from disk
      for (final photo in photos) {
        if (photo.path.isNotEmpty) {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
        }
      }
      // Delete records from database
      final ids = photos.map((p) => p.id).toList();
      await _dao.deletePhotos(ids);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('Failed to delete photos', e));
    }
  }

  Future<Result<void>> removeIssue(String id, QualityIssue issue) async {
    try {
      await _dao.removeIssue(id, issue);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to remove issue', e));
    }
  }

  void invalidate() => _cache.invalidatePrefix('cleanup:');
}
