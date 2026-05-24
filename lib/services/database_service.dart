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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN drive_file_id TEXT');
      await db.execute('ALTER TABLE photo_assets ADD COLUMN drive_md5 TEXT');
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN is_drive_only INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN is_reviewed INTEGER NOT NULL DEFAULT 0');
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
        issues TEXT,
        suggested_name TEXT,
        is_backed_up INTEGER NOT NULL DEFAULT 0,
        p_hash TEXT,
        d_hash TEXT,
        drive_file_id TEXT,
        drive_md5 TEXT,
        is_drive_only INTEGER NOT NULL DEFAULT 0,
        is_reviewed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE vault_documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        image_path TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 5,
        added_at INTEGER NOT NULL,
        notes TEXT,
        tags TEXT
      )
    ''');

    // Full-text search virtual table for vault
    await db.execute('''
      CREATE VIRTUAL TABLE vault_fts USING fts4(
        id TEXT,
        title TEXT,
        notes TEXT,
        tags TEXT
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_photo_category ON photo_assets(category)');
    await db.execute(
        'CREATE INDEX idx_photo_backed_up ON photo_assets(is_backed_up)');
  }

  // ── Photo Assets ──────────────────────────────────────────────────────────

  Future<void> upsertPhoto(PhotoAsset asset) async {
    final database = await db;
    await database.insert(
      'photo_assets',
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    final rows = await database.query('photo_assets');
    return rows.map(PhotoAsset.fromMap).toList();
  }

  /// Returns only IDs — used by incremental scan to skip already-processed photos.
  /// Much cheaper than loading full PhotoAsset objects.
  Future<List<String>> getAllPhotoIds() async {
    final database = await db;
    final rows = await database.query('photo_assets', columns: ['id']);
    return rows.map((r) => r['id'] as String).toList();
  }

  // ── Count-only queries (no object allocation) ───────────────────────────

  Future<int> getPhotoCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets');
    return result.first['cnt'] as int;
  }

  Future<int> getLocalPhotoCount() async {
    final database = await db;
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_drive_only = 0');
    return result.first['cnt'] as int;
  }

  Future<int> getDuplicateCount() async {
    final database = await db;
    final idx = QualityIssue.duplicate.index.toString();
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?',
        ['%,$idx,%', '%,$idx', '$idx,%', idx]);
    return result.first['cnt'] as int;
  }

  Future<int> getJunkCount() async {
    final database = await db;
    final idx = QualityIssue.junk.index.toString();
    final result = await database.rawQuery(
        'SELECT COUNT(*) as cnt FROM photo_assets WHERE issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?',
        ['%,$idx,%', '%,$idx', '$idx,%', idx]);
    return result.first['cnt'] as int;
  }

  /// Aggregate storage stats using SQL — returns raw numbers without
  /// loading any PhotoAsset objects into memory.
  ///
  /// Issues are stored as comma-separated indices (e.g. "0,3").
  /// We match with boundary-aware patterns to avoid false positives
  /// if the enum ever grows past single digits.
  Future<Map<String, int>> getStorageAggregates() async {
    final database = await db;
    final dupIdx = QualityIssue.duplicate.index.toString();
    final junkIdx = QualityIssue.junk.index.toString();
    // Match: between commas, end of string, start of string, or exact value
    final dupPatterns = ['%,$dupIdx,%', '%,$dupIdx', '$dupIdx,%', dupIdx];
    final junkPatterns = ['%,$junkIdx,%', '%,$junkIdx', '$junkIdx,%', junkIdx];

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
    ''', [
      ...dupPatterns, // duplicate_bytes
      ...dupPatterns, // duplicate_count
      ...junkPatterns, // junk_bytes
      ...junkPatterns, // junk_count
    ]);
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

  // ── Paginated queries ───────────────────────────────────────────────────

  Future<List<PhotoAsset>> getPhotosPaginated({
    required int limit,
    required int offset,
    String? orderBy,
  }) async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      limit: limit,
      offset: offset,
      orderBy: orderBy ?? 'created_at DESC',
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getPhotosByCategoryPaginated(
    PhotoCategory cat, {
    required int limit,
    required int offset,
  }) async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'category = ?',
      whereArgs: [cat.index],
      limit: limit,
      offset: offset,
      orderBy: 'created_at DESC',
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<int> getPhotosCountByCategory(PhotoCategory cat) async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM photo_assets WHERE category = ?',
      [cat.index],
    );
    return result.first['cnt'] as int;
  }

  Future<int> getUnreviewedCount() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) as cnt FROM photo_assets WHERE is_reviewed = 0 AND is_drive_only = 0',
    );
    return result.first['cnt'] as int;
  }

  // ── Issue-filtered queries for cleanup screen ───────────────────────────

  /// Returns photos with a specific issue, unreviewed only.
  /// Used by cleanup tabs instead of loading all photos and filtering client-side.
  Future<List<PhotoAsset>> getPhotosByIssue(QualityIssue issue) async {
    final database = await db;
    final idx = issue.index.toString();
    final rows = await database.rawQuery(
      'SELECT * FROM photo_assets WHERE is_reviewed = 0 AND is_drive_only = 0 AND (issues LIKE ? OR issues LIKE ? OR issues LIKE ? OR issues = ?) ORDER BY created_at DESC',
      ['%,$idx,%', '%,$idx', '$idx,%', idx],
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  /// Returns backed-up photos (for cleanup "Backed Up" tab).
  Future<List<PhotoAsset>> getBackedUpPhotosForCleanup() async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'is_backed_up = 1 AND is_drive_only = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  /// Fetch specific photos by ID — avoids loading all photos when only
  /// a few are needed (e.g. for delete/compress operations).
  Future<List<PhotoAsset>> getPhotosByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final database = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await database.rawQuery(
      'SELECT * FROM photo_assets WHERE id IN ($placeholders)',
      ids,
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getPhotosByCategory(PhotoCategory cat) async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'category = ?',
      whereArgs: [cat.index],
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getBackedUpPhotos() async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'is_backed_up = 1',
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<void> markReviewed(String id, {bool reviewed = true}) async {
    final database = await db;
    await database.update(
      'photo_assets',
      {'is_reviewed': reviewed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllReviewed(List<String> ids,
      {bool reviewed = true}) async {
    final database = await db;
    final batch = database.batch();
    for (final id in ids) {
      batch.update(
        'photo_assets',
        {'is_reviewed': reviewed ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<PhotoAsset>> getUnreviewedPhotos() async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'is_reviewed = 0 AND is_drive_only = 0',
      orderBy: 'created_at DESC',
    );
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

  Future<List<PhotoAsset>> getDriveOnlyPhotos() async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'is_drive_only = 1',
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  Future<List<PhotoAsset>> getDrivePhotos() async {
    final database = await db;
    final rows = await database.query(
      'photo_assets',
      where: 'drive_file_id IS NOT NULL',
    );
    return rows.map(PhotoAsset.fromMap).toList();
  }

  /// Returns local photos whose MD5 matches a Drive file MD5 — exact duplicates.
  Future<List<PhotoAsset>> getLocalDriveDuplicates() async {
    final database = await db;
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

  // ── Vault Documents ───────────────────────────────────────────────────────

  Future<void> insertDocument(VaultDocument doc) async {
    final database = await db;
    await database.insert('vault_documents', doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Remove old FTS entry before inserting to prevent duplicates on upsert
    await database.delete('vault_fts', where: 'id = ?', whereArgs: [doc.id]);
    await database.insert('vault_fts', {
      'id': doc.id,
      'title': doc.title,
      'notes': doc.notes ?? '',
      'tags': doc.tags.join(' '),
    });
  }

  Future<List<VaultDocument>> getAllDocuments() async {
    final database = await db;
    final rows = await database.query('vault_documents',
        orderBy: 'added_at DESC');
    return rows.map(VaultDocument.fromMap).toList();
  }

  Future<List<VaultDocument>> searchDocuments(String query) async {
    final database = await db;
    final ftsRows = await database.rawQuery(
      'SELECT id FROM vault_fts WHERE vault_fts MATCH ?',
      [query],
    );
    if (ftsRows.isEmpty) return [];
    final ids = ftsRows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await database.rawQuery(
      'SELECT * FROM vault_documents WHERE id IN ($placeholders)',
      ids,
    );
    return rows.map(VaultDocument.fromMap).toList();
  }

  Future<void> deleteDocument(String id) async {
    final database = await db;
    await database
        .delete('vault_documents', where: 'id = ?', whereArgs: [id]);
    await database.delete('vault_fts', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all rows from all tables and resets the DB connection.
  Future<void> clearAll() async {
    final database = await db;
    await database.delete('photo_assets');
    await database.delete('vault_documents');
    await database.execute('DROP TABLE IF EXISTS vault_fts');
    await database.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS vault_fts USING fts4(
        id TEXT,
        title TEXT,
        notes TEXT,
        tags TEXT
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
