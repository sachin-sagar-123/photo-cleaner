import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../models/photo_asset.dart';

/// Data access for photo scan operations.
class PhotoDao {
  final AppDatabase _db;
  PhotoDao(this._db);

  Future<void> upsertPhoto(PhotoAsset asset) async {
    final database = await _db.db;
    await database.insert('photo_assets', asset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertPhotos(List<PhotoAsset> assets) async {
    final database = await _db.db;
    final batch = database.batch();
    for (final a in assets) {
      batch.insert('photo_assets', a.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> getAllPhotoIds() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets', columns: ['id']);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<List<PhotoAsset>> getAllPhotos() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<void> deletePhoto(String id) async {
    final database = await _db.db;
    await database.delete('photo_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePhotos(List<String> ids) async {
    final database = await _db.db;
    final batch = database.batch();
    for (final id in ids) {
      batch.delete('photo_assets', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<PhotoAsset>> getPhotosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final database = await _db.db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await database.rawQuery(
        'SELECT * FROM photo_assets WHERE id IN ($placeholders)', ids);
    return rows.map(PhotoAsset.fromMap).toList();
  }
}
