import '../../../core/database/app_database.dart';
import '../../../models/photo_asset.dart';

/// Important photos queries.
class ImportantDao {
  final AppDatabase _db;
  ImportantDao(this._db);

  Future<List<PhotoAsset>> getImportantPhotos() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        where: 'is_important = 1', orderBy: 'created_at DESC');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<int> getImportantCount() async {
    final database = await _db.db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_important = 1');
    return result.first['cnt'] as int;
  }

  Future<void> markImportant(String id, {bool important = true}) async {
    final database = await _db.db;
    await database.update('photo_assets',
        {'is_important': important ? 1 : 0, 'is_reviewed': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePhotoPath(String id, String newPath) async {
    final database = await _db.db;
    await database.update('photo_assets', {'path': newPath},
        where: 'id = ?', whereArgs: [id]);
  }
}
