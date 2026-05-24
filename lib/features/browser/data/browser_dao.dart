import '../../../core/database/app_database.dart';
import '../../../models/photo_asset.dart';

/// Browser-specific queries — unreviewed photos and review actions.
class BrowserDao {
  final AppDatabase _db;
  BrowserDao(this._db);

  Future<List<PhotoAsset>> getUnreviewedPhotos() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        where: 'is_reviewed = 0 AND is_drive_only = 0',
        orderBy: 'created_at DESC');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<void> markReviewed(String id, {bool reviewed = true}) async {
    final database = await _db.db;
    await database.update('photo_assets',
        {'is_reviewed': reviewed ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllReviewed(List<String> ids, {bool reviewed = true}) async {
    final database = await _db.db;
    final batch = database.batch();
    for (final id in ids) {
      batch.update('photo_assets', {'is_reviewed': reviewed ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
