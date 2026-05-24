import 'package:sqflite/sqflite.dart';

/// All database migrations in one place.
class Migrations {
  static const currentVersion = 4;

  static Future<void> create(Database db, int version) async {
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
        is_reviewed INTEGER NOT NULL DEFAULT 0,
        is_important INTEGER NOT NULL DEFAULT 0
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

  static Future<void> upgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN drive_file_id TEXT');
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN drive_md5 TEXT');
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN is_drive_only INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN is_reviewed INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE photo_assets ADD COLUMN is_important INTEGER NOT NULL DEFAULT 0');
    }
  }
}
