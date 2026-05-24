import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../models/vault_document.dart';

/// Vault document queries.
class VaultDao {
  final AppDatabase _db;
  VaultDao(this._db);

  Future<void> insertDocument(VaultDocument doc) async {
    final database = await _db.db;
    await database.insert('vault_documents', doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await database.delete('vault_fts', where: 'id = ?', whereArgs: [doc.id]);
    await database.insert('vault_fts', {
      'id': doc.id,
      'title': doc.title,
      'notes': doc.notes ?? '',
      'tags': doc.tags.join(' '),
    });
  }

  Future<List<VaultDocument>> getAllDocuments() async {
    final database = await _db.db;
    final rows = await database.query('vault_documents',
        orderBy: 'added_at DESC');
    return rows.map(VaultDocument.fromMap).toList();
  }

  Future<List<VaultDocument>> searchDocuments(String query) async {
    final database = await _db.db;
    final ftsRows = await database.rawQuery(
        'SELECT id FROM vault_fts WHERE vault_fts MATCH ?', [query]);
    if (ftsRows.isEmpty) return [];
    final ids = ftsRows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await database.rawQuery(
        'SELECT * FROM vault_documents WHERE id IN ($placeholders)', ids);
    return rows.map(VaultDocument.fromMap).toList();
  }

  Future<void> deleteDocument(String id) async {
    final database = await _db.db;
    await database.delete('vault_documents', where: 'id = ?', whereArgs: [id]);
    await database.delete('vault_fts', where: 'id = ?', whereArgs: [id]);
  }
}
