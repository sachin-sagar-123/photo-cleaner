import '../../../core/database/app_database.dart';
import '../../../models/photo_asset.dart';

/// Drive sync queries.
class DriveDao {
  final AppDatabase _db;
  DriveDao(this._db);

  Future<List<PhotoAsset>> getBackedUpPhotos() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        where: 'is_backed_up = 1');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getDriveOnlyPhotos() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        where: 'is_drive_only = 1');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getDrivePhotos() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        where: 'drive_file_id IS NOT NULL');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getLocalDriveDuplicates() async {
    final database = await _db.db;
    final rows = await database.rawQuery('''
      SELECT * FROM photo_assets
      WHERE is_drive_only = 0
        AND drive_md5 IS NOT NULL
        AND drive_md5 IN (
          SELECT drive_md5 FROM photo_assets WHERE is_drive_only = 1
        )
    ''');
    return rows.map(PhotoAsset.fromMap).toList();
  }
}
