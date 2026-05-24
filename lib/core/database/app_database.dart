import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// Single database instance shared across all feature DAOs.
class AppDatabase {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'photo_cleaner.db');
    return openDatabase(
      path,
      version: Migrations.currentVersion,
      onCreate: Migrations.create,
      onUpgrade: Migrations.upgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Clear all data — used from settings.
  Future<void> clearAll() async {
    final d = await db;
    await d.delete('photos');
    await d.delete('vault_documents');
  }
}
