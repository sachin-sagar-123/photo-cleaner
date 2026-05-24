import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../models/vault_document.dart';
import 'vault_dao.dart';

/// Cached repository for vault documents with FTS search.
class VaultRepository {
  final VaultDao _dao;
  final MemoryCache _cache;

  static const _allKey = 'vault:all';
  static const _ttl = Duration(minutes: 5);

  VaultRepository(this._dao, this._cache);

  Future<Result<List<VaultDocument>>> getAllDocuments() async {
    final cached = _cache.get<List<VaultDocument>>(_allKey);
    if (cached != null) return Success(cached);

    try {
      final docs = await _dao.getAllDocuments();
      _cache.set(_allKey, docs, ttl: _ttl);
      return Success(docs);
    } catch (e) {
      return Failure(DatabaseException('Failed to load vault documents', e));
    }
  }

  Future<Result<List<VaultDocument>>> searchDocuments(String query) async {
    final key = 'vault:search:$query';
    final cached = _cache.get<List<VaultDocument>>(key);
    if (cached != null) return Success(cached);

    try {
      final docs = await _dao.searchDocuments(query);
      _cache.set(key, docs, ttl: _ttl);
      return Success(docs);
    } catch (e) {
      return Failure(DatabaseException('Vault search failed', e));
    }
  }

  Future<Result<void>> insertDocument(VaultDocument doc) async {
    try {
      await _dao.insertDocument(doc);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to save document', e));
    }
  }

  Future<Result<void>> deleteDocument(String id) async {
    try {
      await _dao.deleteDocument(id);
      invalidate();
      return const Success(null);
    } catch (e) {
      return Failure(DatabaseException('Failed to delete document', e));
    }
  }

  void invalidate() => _cache.invalidatePrefix('vault:');
}
