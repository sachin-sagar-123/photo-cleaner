import '../../../core/database/app_database.dart';
import '../../../models/models.dart';

/// Dashboard-specific queries — counts and aggregates only, no full objects.
class DashboardDao {
  final AppDatabase _db;
  DashboardDao(this._db);

  Future<int> getPhotoCount() async {
    final database = await _db.db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets');
    return result.first['cnt'] as int;
  }

  Future<int> getLocalPhotoCount() async {
    final database = await _db.db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_drive_only = 0');
    return result.first['cnt'] as int;
  }

  Future<int> getUnreviewedCount() async {
    final database = await _db.db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_reviewed = 0 AND is_drive_only = 0');
    return result.first['cnt'] as int;
  }

  Future<int> getImportantCount() async {
    final database = await _db.db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_important = 1');
    return result.first['cnt'] as int;
  }

  Future<int> getPhotosCountByCategory(PhotoCategory cat) async {
    final database = await _db.db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE category = ?',
        [cat.index]);
    return result.first['cnt'] as int;
  }

  /// Single SQL aggregate — replaces loading all PhotoAsset objects.
  Future<Map<String, int>> getStorageAggregates() async {
    final database = await _db.db;
    final dupIdx = QualityIssue.duplicate.index.toString();
    final junkIdx = QualityIssue.junk.index.toString();
    final dupP = ['%,$dupIdx,%', '%,$dupIdx', '$dupIdx,%', dupIdx];
    final junkP = ['%,$junkIdx,%', '%,$junkIdx', '$junkIdx,%', junkIdx];

    final result = await database.rawQuery('''
      SELECT
        COUNT(*) as total_photos,
        COALESCE(SUM(size_bytes), 0) as total_bytes,
        COALESCE(SUM(CASE WHEN is_backed_up = 1 THEN size_bytes ELSE 0 END), 0) as backed_up_bytes,
        COALESCE(SUM(CASE WHEN (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) THEN size_bytes ELSE 0 END), 0) as duplicate_bytes,
        COALESCE(SUM(CASE WHEN (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) THEN 1 ELSE 0 END), 0) as duplicate_count,
        COALESCE(SUM(CASE WHEN (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) THEN size_bytes ELSE 0 END), 0) as junk_bytes,
        COALESCE(SUM(CASE WHEN (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) THEN 1 ELSE 0 END), 0) as junk_count
      FROM photo_assets
      WHERE is_drive_only = 0
    ''', [...dupP, ...dupP, ...junkP, ...junkP]);

    final row = result.first;
    return {
      'total_photos': row['total_photos'] as int,
      'total_bytes': row['total_bytes'] as int,
      'backed_up_bytes': row['backed_up_bytes'] as int,
      'duplicate_bytes': row['duplicate_bytes'] as int,
      'duplicate_count': row['duplicate_count'] as int,
      'junk_bytes': row['junk_bytes'] as int,
      'junk_count': row['junk_count'] as int,
    };
  }
}
