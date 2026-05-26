import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'photo_cleaner.db'),
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE photo_assets ADD COLUMN drive_file_id TEXT');
      await db.execute('ALTER TABLE photo_assets ADD COLUMN drive_md5 TEXT');
      await db.execute('ALTER TABLE photo_assets ADD COLUMN is_drive_only INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE photo_assets ADD COLUMN is_reviewed INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE photo_assets ADD COLUMN is_important INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE photo_assets ADD COLUMN ai_category TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photo_assets (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        name TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        category INTEGER NOT NULL DEFAULT 5,
        ai_category TEXT,
        issues TEXT,
        suggested_name TEXT,
        is_backed_up INTEGER NOT NULL DEFAULT 0,
        p_hash TEXT,
        d_hash TEXT,
        drive_file_id TEXT,
        drive_md5 TEXT,
        is_drive_only INTEGER NOT NULL DEFAULT 0,
        is_reviewed INTEGER NOT NULL DEFAULT 0,
        is_important INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_photo_category ON photo_assets(category)');
    await db.execute('CREATE INDEX idx_photo_backed_up ON photo_assets(is_backed_up)');
  }

  // ── Photo CRUD ──────────────────────────────────────────────────────────

  Future<void> upsertPhoto(PhotoAsset asset) async {
    final database = await db;
    await database.insert('photo_assets', asset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertPhotos(List<PhotoAsset> assets) async {
    final database = await db;
    final batch = database.batch();
    for (final a in assets) {
      batch.insert('photo_assets', a.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<PhotoAsset>> getAllPhotos() async {
    final database = await db;
    final rows = await database.query('photo_assets',
        where: 'is_drive_only = 0');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<String>> getAllPhotoIds() async {
    final database = await db;
    final rows = await database.query('photo_assets', columns: ['id']);
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<List<PhotoAsset>> getPhotosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final database = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await database.rawQuery(
      'SELECT * FROM photo_assets WHERE id IN ($placeholders)', ids);
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<void> deletePhoto(String id) async {
    final database = await db;
    await database.delete('photo_assets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePhotos(List<String> ids) async {
    final database = await db;
    final batch = database.batch();
    for (final id in ids) {
      batch.delete('photo_assets', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // ── Issue queries ───────────────────────────────────────────────────────

  /// Returns photos with a specific issue (blurry or duplicate).
  Future<List<PhotoAsset>> getPhotosByIssue(QualityIssue issue) async {
    final database = await db;
    final idx = issue.index.toString();
    final rows = await database.rawQuery(
      'SELECT * FROM photo_assets WHERE is_drive_only = 0 AND '
      '(issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) '
      'ORDER BY size_bytes DESC',
      ['%,$idx,%', '%,$idx', '$idx,%', idx],
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  // ── Important ───────────────────────────────────────────────────────────

  Future<void> markImportant(String id, {bool important = true}) async {
    final database = await db;
    await database.update('photo_assets',
      {'is_important': important ? 1 : 0, 'is_reviewed': 1},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePhotoPath(String id, String newPath) async {
    final database = await db;
    await database.update('photo_assets', {'path': newPath},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PhotoAsset>> getImportantPhotos() async {
    final database = await db;
    final rows = await database.query('photo_assets',
      where: 'is_important = 1', orderBy: 'created_at DESC');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<int> getImportantCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_important = 1');
    return result.first['cnt'] as int;
  }

  // ── Review ──────────────────────────────────────────────────────────────

  Future<void> markReviewed(String id, {bool reviewed = true}) async {
    final database = await db;
    await database.update('photo_assets',
      {'is_reviewed': reviewed ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllReviewed(List<String> ids, {bool reviewed = true}) async {
    final database = await db;
    final batch = database.batch();
    for (final id in ids) {
      batch.update('photo_assets', {'is_reviewed': reviewed ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeIssue(String id, QualityIssue issue) async {
    final database = await db;
    final rows = await database.query('photo_assets',
      columns: ['issues'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;

    final currentIssues = (rows.first['issues'] as String?)
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s))
            .toList() ?? [];
    currentIssues.remove(issue.index);

    await database.update('photo_assets', {
      'issues': currentIssues.join(','),
      'is_reviewed': 1,
      'is_important': 1,
    }, where: 'id = ?', whereArgs: [id]);
  }

  // ── Aggregates ──────────────────────────────────────────────────────────

  Future<int> getPhotoCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_drive_only = 0');
    return result.first['cnt'] as int;
  }

  Future<Map<String, int>> getStorageAggregates() async {
    final database = await db;
    final dupIdx = QualityIssue.duplicate.index.toString();
    final dupP = ['%,$dupIdx,%', '%,$dupIdx', '$dupIdx,%', dupIdx];

    final result = await database.rawQuery('''
      SELECT
        COUNT(*) as total_photos,
        COALESCE(SUM(size_bytes), 0) as total_bytes,
        COALESCE(SUM(CASE WHEN is_backed_up = 1 THEN size_bytes ELSE 0 END), 0) as backed_up_bytes,
        COALESCE(SUM(CASE WHEN (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) THEN size_bytes ELSE 0 END), 0) as duplicate_bytes,
        COALESCE(SUM(CASE WHEN (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) THEN 1 ELSE 0 END), 0) as duplicate_count
      FROM photo_assets
      WHERE is_drive_only = 0
    ''', [...dupP, ...dupP]);

    final row = result.first;
    return {
      'total_photos': row['total_photos'] as int,
      'total_bytes': row['total_bytes'] as int,
      'backed_up_bytes': row['backed_up_bytes'] as int,
      'duplicate_bytes': row['duplicate_bytes'] as int,
      'duplicate_count': row['duplicate_count'] as int,
    };
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final database = await db;
    await database.delete('photo_assets');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
