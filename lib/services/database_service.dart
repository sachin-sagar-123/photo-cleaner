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
      version: 2,
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
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photo_assets (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        name TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        category INTEGER NOT NULL DEFAULT 6,
        issues TEXT,
        suggested_name TEXT,
        is_backed_up INTEGER NOT NULL DEFAULT 0,
        p_hash TEXT,
        d_hash TEXT,
        drive_file_id TEXT,
        drive_md5 TEXT,
        is_drive_only INTEGER NOT NULL DEFAULT 0
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
    final ids = ftsRows.map((r) => "'${r['id']}'").join(',');
    final rows = await database.rawQuery(
      'SELECT * FROM vault_documents WHERE id IN ($ids)',
    );
    return rows.map(VaultDocument.fromMap).toList();
  }

  Future<void> deleteDocument(String id) async {
    final database = await db;
    await database
        .delete('vault_documents', where: 'id = ?', whereArgs: [id]);
    await database.delete('vault_fts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async => _db?.close();
}
