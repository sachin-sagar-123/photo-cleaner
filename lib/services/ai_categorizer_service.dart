import 'dart:async';
import 'dart:io';

import '../models/photo_asset.dart';
import 'ai_service.dart';
import 'database_service.dart';

/// Progress of AI batch categorization.
class AICategorizeProgress {
  final int processed;
  final int total;
  final int succeeded;
  final int failed;
  final String currentFile;
  final bool isDone;

  const AICategorizeProgress({
    required this.processed,
    required this.total,
    required this.succeeded,
    required this.failed,
    this.currentFile = '',
    this.isDone = false,
  });

  double get percent => total > 0 ? processed / total : 0;
}

/// Batch AI categorization service.
///
/// Fetches uncategorized photos from DB, sends each to the AI vision API,
/// and writes the result back. Rate-limited to avoid API throttling.
class AICategorizer {
  final AIService _ai;
  final DatabaseService _db;

  /// Delay between API calls to respect rate limits.
  /// Gemini free tier: 15 RPM → 4000ms. Paid: 60 RPM → 1000ms.
  /// Grok: similar limits.
  static const int _delayMs = 1500;

  /// Photos per batch fetch from DB.
  static const int _batchSize = 50;

  bool _cancelled = false;

  AICategorizer(this._ai, this._db);

  /// Cancel a running categorization.
  void cancel() => _cancelled = true;

  /// Run AI categorization on all uncategorized photos.
  /// Yields progress updates. Stops on cancel or when all photos are done.
  Stream<AICategorizeProgress> categorizeAll() async* {
    _cancelled = false;

    if (!_ai.isConfigured) {
      yield const AICategorizeProgress(
        processed: 0, total: 0, succeeded: 0, failed: 0,
        currentFile: 'AI not configured — add API key in Settings',
        isDone: true,
      );
      return;
    }

    final totalCount = await _db.getUncategorizedCount();
    if (totalCount == 0) {
      yield const AICategorizeProgress(
        processed: 0, total: 0, succeeded: 0, failed: 0,
        currentFile: 'All photos already categorized',
        isDone: true,
      );
      return;
    }

    int processed = 0;
    int succeeded = 0;
    int failed = 0;

    yield AICategorizeProgress(
      processed: 0, total: totalCount, succeeded: 0, failed: 0,
      currentFile: 'Starting AI categorization...',
    );

    while (!_cancelled) {
      final batch = await _db.getUncategorizedPhotos(limit: _batchSize);
      if (batch.isEmpty) break;

      for (final photo in batch) {
        if (_cancelled) break;

        final id = photo['id']!;
        final path = photo['path']!;
        final filename = path.split('/').last;

        yield AICategorizeProgress(
          processed: processed, total: totalCount,
          succeeded: succeeded, failed: failed,
          currentFile: filename,
        );

        try {
          // Verify file exists before sending to API
          if (!await File(path).exists()) {
            failed++;
            processed++;
            // Mark as 'other' so we don't retry missing files
            await _db.updateAICategory(id, PhotoCategory.other.name);
            continue;
          }

          final category = await _ai.categorizePhoto(path);
          await _db.updateAICategory(id, category.name);
          succeeded++;
        } catch (_) {
          failed++;
          // Don't mark failed photos — they'll be retried next run
        }

        processed++;

        // Rate limiting
        if (!_cancelled) {
          await Future.delayed(const Duration(milliseconds: _delayMs));
        }
      }
    }

    yield AICategorizeProgress(
      processed: processed, total: totalCount,
      succeeded: succeeded, failed: failed,
      currentFile: _cancelled ? 'Cancelled' : 'Done',
      isDone: true,
    );
  }

  /// Categorize a single photo by ID. Used for on-demand re-categorization.
  Future<PhotoCategory?> categorizeOne(String photoId, String path) async {
    if (!_ai.isConfigured) return null;
    if (!await File(path).exists()) return null;

    try {
      final category = await _ai.categorizePhoto(path);
      await _db.updateAICategory(photoId, category.name);
      return category;
    } catch (_) {
      return null;
    }
  }

  /// Re-categorize photos that already have an AI category.
  /// Clears existing AI categories first, then runs full categorization.
  Stream<AICategorizeProgress> recategorizeAll() async* {
    // Clear all existing AI categories
    final database = await _db.db;
    await database.update('photo_assets', {'ai_category': null});

    // Run full categorization
    yield* categorizeAll();
  }
}
