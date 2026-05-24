import 'dart:io';

import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/photo_asset.dart';
import 'important_dao.dart';

/// Cached repository for important photos.
class ImportantRepository {
  final ImportantDao _dao;
  final MemoryCache _cache;

  static const _listKey = 'important:list';
  static const _countKey = 'important:count';
  static const _ttl = Duration(minutes: 3);

  ImportantRepository(this._dao, this._cache);

  Future<Result<List<PhotoAsset>>> getImportantPhotos() async {
    final cached = _cache.get<List<PhotoAsset>>(_listKey);
    if (cached != null) return Success(cached);

    try {
      final photos = await _dao.getImportantPhotos();
      _cache.set(_listKey, photos, ttl: _ttl);
      return Success(photos);
    } catch (e) {
      return Failure(DatabaseException('Failed to load important photos', e));
    }
  }

  Future<Result<int>> getImportantCount() async {
    final cached = _cache.get<int>(_countKey);
    if (cached != null) return Success(cached);

    try {
      final count = await _dao.getImportantCount();
      _cache.set(_countKey, count, ttl: _ttl);
      return Success(count);
    } catch (e) {
      return Failure(DatabaseException('Failed to load count', e));
    }
  }

  Future<Result<void>> markImportant(String id, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return Failure(StorageException('Source file not found: $sourcePath'));
      }

      // Copy file to Important folder
      final importantDir = Directory('/storage/emulated/0/DCIM/PhotoCleaner Important');
      if (!await importantDir.exists()) {
        await importantDir.create(recursive: true);
      }

      // Use timestamp suffix to avoid filename collisions
      final baseName = sourceFile.uri.pathSegments.last;
      final ext = baseName.contains('.') ? '.${baseName.split('.').last}' : '';
      final nameWithoutExt = baseName.contains('.')
          ? baseName.substring(0, baseName.lastIndexOf('.'))
          : baseName;
      final destName = '${nameWithoutExt}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = '${importantDir.path}/$destName';
      await sourceFile.copy(destPath);

      await _dao.markImportant(id);
      await _dao.updatePhotoPath(id, destPath);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(StorageException('Failed to mark important', e));
    }
  }

  Future<Result<void>> removeImportant(String id) async {
    try {
      await _dao.markImportant(id, important: false);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to remove important', e));
    }
  }

  void invalidate() => _cache.invalidatePrefix('important:');
}
