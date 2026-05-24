import '../../../core/database/app_database.dart';
import '../../../models/models.dart';

/// Cleanup-specific queries.
class CleanupDao {
  final AppDatabase _db;
  CleanupDao(this._db);

  Future<List<PhotoAsset>> getPhotosByIssue(QualityIssue issue) async {
    final database = await _db.db;
    final idx = issue.index.toString();
    final rows = await database.rawQuery(
      'SELECT * FROM photo_assets WHERE is_reviewed = 0 AND is_drive_only = 0 '
      'AND (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) '
      'ORDER BY created_at DESC',
      ['%,$idx,%', '%,$idx', '$idx,%', idx],
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getBackedUpPhotosForCleanup() async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        where: 'is_backed_up = 1 AND is_drive_only = 0',
        orderBy: 'created_at DESC');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<int> getDuplicateCount() async {
    final database = await _db.db;
    final idx = QualityIssue.duplicate.index.toString();
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets '
        'WHERE issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?',
        ['%,$idx,%', '%,$idx', '$idx,%', idx]);
    return result.first['cnt'] as int;
  }

  Future<int> getJunkCount() async {
    final database = await _db.db;
    final idx = QualityIssue.junk.index.toString();
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets '
        'WHERE issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?',
        ['%,$idx,%', '%,$idx', '$idx,%', idx]);
    return result.first['cnt'] as int;
  }

  Future<void> removeIssue(String id, QualityIssue issue) async {
    final database = await _db.db;
    final rows = await database.query('photo_assets',
        columns: ['issues'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;

    final currentIssues = (rows.first['issues'] as String?)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s))
            .toList() ??
        [];
    currentIssues.remove(issue.index);

    await database.update('photo_assets', {
      'issues': currentIssues.join(','),
      'is_reviewed': 1,
      'is_important': 1,
    }, where: 'id = ?', whereArgs: [id]);
  }
}
