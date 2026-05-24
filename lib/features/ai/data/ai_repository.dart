import '../../../core/cache/cache_entry.dart';
import '../../../core/error/result.dart';
import '../../../services/ai_service.dart';

/// Cached repository for AI operations.
/// Caches analysis results per photo path to avoid re-analyzing.
class AIRepository {
  final AIService _service;
  final MemoryCache _cache;

  static const _ttl = Duration(minutes: 30);

  AIRepository(this._service, this._cache);

  bool get isConfigured => _service.isConfigured;
  AIProvider get provider => _service.provider;

  Future<Result<String>> generateCaption(String imagePath) async {
    final key = 'ai:caption:$imagePath';
    final cached = _cache.get<String>(key);
    if (cached != null) return Success(cached);

    try {
      final caption = await _service.generateCaption(imagePath);
      _cache.set(key, caption, ttl: _ttl);
      return Success(caption);
    } catch (e) {
      return Failure(AIException('Caption generation failed', e));
    }
  }

  Future<Result<PhotoAICategory>> categorizePhoto(String imagePath) async {
    final key = 'ai:category:$imagePath';
    final cached = _cache.get<PhotoAICategory>(key);
    if (cached != null) return Success(cached);

    try {
      final category = await _service.categorizePhoto(imagePath);
      _cache.set(key, category, ttl: _ttl);
      return Success(category);
    } catch (e) {
      return Failure(AIException('Categorization failed', e));
    }
  }

  Future<Result<PhotoAIAnalysis>> analyzePhoto(String imagePath) async {
    final key = 'ai:analysis:$imagePath';
    final cached = _cache.get<PhotoAIAnalysis>(key);
    if (cached != null) return Success(cached);

    try {
      final analysis = await _service.analyzePhoto(imagePath);
      _cache.set(key, analysis, ttl: _ttl);
      return Success(analysis);
    } catch (e) {
      return Failure(AIException('Analysis failed', e));
    }
  }

  Future<Result<String>> chat(String message, {String? imagePath}) async {
    try {
      final response = await _service.chat(message, imagePath: imagePath);
      return Success(response);
    } catch (e) {
      return Failure(AIException('Chat failed', e));
    }
  }

  Future<void> configure(AIProvider provider, String key) async {
    await _service.setProvider(provider);
    await _service.setApiKey(provider, key);
  }

  void resetChat() => _service.resetChat();
  void invalidate() => _cache.invalidatePrefix('ai:');
}
