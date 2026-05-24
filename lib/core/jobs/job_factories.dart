import '../../models/models.dart';
import '../../services/compression_service.dart';
import 'job_queue.dart';

/// Typed factory methods for creating jobs from app operations.
/// Keeps job creation consistent and avoids raw Job<T> construction
/// scattered across screens.
class JobFactories {
  /// Create a compression job for a single photo.
  static Job<CompressionResult?> compression({
    required String id,
    required String path,
    required CompressionMode mode,
    required CompressionService service,
    void Function(CompressionResult? result)? onComplete,
  }) {
    return Job<CompressionResult?>(
      id: 'compress:$id',
      type: 'compression',
      execute: () => service.compress(path, mode),
      maxRetries: 2,
      initialBackoff: const Duration(seconds: 1),
      priority: JobPriority.normal,
      onComplete: onComplete,
    );
  }

  /// Create a batch of compression jobs.
  static List<Job<CompressionResult?>> compressionBatch({
    required List<PhotoAsset> photos,
    required CompressionMode mode,
    required CompressionService service,
    void Function(CompressionResult? result)? onEachComplete,
  }) {
    return photos
        .map((p) => compression(
              id: p.id,
              path: p.path,
              mode: mode,
              service: service,
              onComplete: onEachComplete,
            ))
        .toList();
  }

  /// Create a file deletion job with retry for locked files.
  static Job<void> deletion({
    required String id,
    required String path,
    required Future<void> Function(String path) deleteFunc,
  }) {
    return Job<void>(
      id: 'delete:$id',
      type: 'deletion',
      execute: () => deleteFunc(path),
      maxRetries: 3,
      initialBackoff: const Duration(seconds: 2),
      priority: JobPriority.high,
    );
  }

  /// Create an AI analysis job for a single photo.
  static Job<T> aiAnalysis<T>({
    required String id,
    required String path,
    required Future<T> Function(String path) analyzeFunc,
    void Function(T result)? onComplete,
  }) {
    return Job<T>(
      id: 'ai:$id',
      type: 'ai_analysis',
      execute: () => analyzeFunc(path),
      maxRetries: 2,
      initialBackoff: const Duration(seconds: 5),
      priority: JobPriority.low,
      onComplete: onComplete,
    );
  }
}
