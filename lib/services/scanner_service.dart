import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'duplicate_detector_service.dart';
import 'ml_analysis_service.dart';
import 'scan_preferences_service.dart';

class ScanProgress {
  final int scanned;
  final int total;
  final int skipped;
  final String currentFile;
  final String phase; // 'loading', 'scanning', 'saving', 'done'

  const ScanProgress({
    required this.scanned,
    required this.total,
    this.skipped = 0,
    required this.currentFile,
    this.phase = 'scanning',
  });

  double get percent => total > 0 ? scanned / total : 0;
}

/// Lightweight result from isolate — no image bytes retained.
class _PhotoProcessResult {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final List<QualityIssue> issues;
  final String? pHash;
  final String? dHash;

  const _PhotoProcessResult({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    required this.issues,
    this.pHash,
    this.dHash,
  });
}

class _PhotoData {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final Uint8List bytes;

  const _PhotoData({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    required this.bytes,
  });
}

/// Scan pipeline focused on duplicate + blurry detection.
///
/// Optimizations vs previous version:
/// 1. Parallel thumbnail I/O (3 concurrent reads vs sequential)
/// 2. Larger batch size (20 vs 5) — 4× fewer isolate spawns
/// 3. Only blur + hash analysis — no classification, junk, low-light
/// 4. Chunked DB writes every 50 photos
class ScannerService {
  final _db = DatabaseService();
  final _scanPrefs = ScanPreferencesService();

  /// 20 photos per isolate batch. At ~200KB/thumbnail = ~4MB peak per batch.
  static const int _batchSize = 20;

  /// Concurrent thumbnail reads.
  static const int _ioConcurrency = 3;

  /// DB write chunk size.
  static const int _dbChunkSize = 50;

  Stream<ScanProgress> scan({bool forceFullRescan = false}) async* {
    final startTime = DateTime.now();

    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    if (!permission.isAuth && !permission.hasAccess) {
      throw Exception(
          'Photo library permission denied. Go to Settings > Apps > PhotoCleaner > Permissions > Photos and videos > Allow all.');
    }

    yield const ScanProgress(
      scanned: 0, total: 0,
      currentFile: 'Loading photo library...',
      phase: 'loading',
    );

    var albums = await PhotoManager.getAssetPathList(
      type: RequestType.image, onlyAll: true,
    );
    if (albums.isEmpty) {
      albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    }
    if (albums.isEmpty) {
      yield const ScanProgress(
          scanned: 0, total: 0, currentFile: 'No photos found', phase: 'done');
      return;
    }

    final seenIds = <String>{};
    final allAssets = <AssetEntity>[];
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      final assets = await album.getAssetListRange(start: 0, end: count);
      for (final asset in assets) {
        if (seenIds.add(asset.id)) allAssets.add(asset);
      }
    }

    final totalOnDevice = allAssets.length;
    if (totalOnDevice == 0) {
      yield const ScanProgress(
          scanned: 0, total: 0, currentFile: 'No photos found', phase: 'done');
      return;
    }

    List<AssetEntity> toProcess;
    int skippedCount = 0;
    final existingIds = forceFullRescan ? <String>[] : await _db.getAllPhotoIds();

    if (forceFullRescan) {
      toProcess = allAssets;
    } else {
      final existingSet = existingIds.toSet();
      toProcess = allAssets.where((a) => !existingSet.contains(a.id)).toList();
      skippedCount = totalOnDevice - toProcess.length;
    }

    // Prune deleted photos from DB
    if (existingIds.isNotEmpty) {
      final staleIds = existingIds.where((id) => !seenIds.contains(id)).toList();
      if (staleIds.isNotEmpty) await _db.deletePhotos(staleIds);
    }

    if (toProcess.isEmpty) {
      yield ScanProgress(
        scanned: totalOnDevice, total: totalOnDevice,
        skipped: skippedCount,
        currentFile: 'All photos already scanned', phase: 'done',
      );
      await _recordScanMetadata(startTime, totalOnDevice);
      return;
    }

    yield ScanProgress(
      scanned: 0, total: toProcess.length, skipped: skippedCount,
      currentFile: 'Starting scan of ${toProcess.length} new photos...',
      phase: 'scanning',
    );

    final pendingResults = <PhotoAsset>[];
    int processed = 0;

    for (int batchStart = 0;
        batchStart < toProcess.length;
        batchStart += _batchSize) {
      final batchEnd = (batchStart + _batchSize).clamp(0, toProcess.length);
      final batchEntities = toProcess.sublist(batchStart, batchEnd);

      // Parallel thumbnail I/O
      final batchPhotos = await _loadThumbnailsParallel(batchEntities);

      if (batchPhotos.isEmpty) {
        processed += batchEntities.length;
        continue;
      }

      List<_PhotoProcessResult> results;
      try {
        results = await Isolate.run(() => _processBatch(batchPhotos));
      } catch (_) {
        processed += batchEntities.length;
        continue;
      }

      final entityMap = {for (final e in batchEntities) e.id: e};
      for (final r in results) {
        pendingResults.add(PhotoAsset(
          id: r.id,
          path: r.path,
          name: r.name,
          sizeBytes: r.sizeBytes,
          createdAt: r.createdAt,
          issues: r.issues,
          pHash: r.pHash,
          dHash: r.dHash,
          entity: entityMap[r.id],
        ));
      }

      processed += batchEntities.length;

      yield ScanProgress(
        scanned: processed, total: toProcess.length,
        skipped: skippedCount,
        currentFile: batchPhotos.last.name,
        phase: 'scanning',
      );

      if (pendingResults.length >= _dbChunkSize) {
        await _db.upsertPhotos(pendingResults);
        pendingResults.clear();
      }
    }

    if (pendingResults.isNotEmpty) {
      yield ScanProgress(
        scanned: processed, total: toProcess.length,
        skipped: skippedCount,
        currentFile: 'Saving to database...', phase: 'saving',
      );
      await _db.upsertPhotos(pendingResults);
    }

    await _recordScanMetadata(startTime, totalOnDevice);

    yield ScanProgress(
      scanned: toProcess.length, total: toProcess.length,
      skipped: skippedCount,
      currentFile: 'Done', phase: 'done',
    );
  }

  /// Load thumbnails with bounded parallelism (3 concurrent).
  Future<List<_PhotoData>> _loadThumbnailsParallel(
      List<AssetEntity> entities) async {
    final results = <_PhotoData>[];
    for (int i = 0; i < entities.length; i += _ioConcurrency) {
      final chunk = entities.sublist(
          i, (i + _ioConcurrency).clamp(0, entities.length));
      final loaded = await Future.wait(chunk.map(_loadOneThumbnail));
      for (final photo in loaded) {
        if (photo != null) results.add(photo);
      }
    }
    return results;
  }

  Future<_PhotoData?> _loadOneThumbnail(AssetEntity entity) async {
    try {
      final file = await entity.file;
      if (file == null) return null;
      final stat = await file.stat();
      final thumbBytes = await entity.thumbnailDataWithSize(
        const ThumbnailSize(1024, 1024), quality: 80,
      );
      if (thumbBytes == null || thumbBytes.isEmpty) return null;
      return _PhotoData(
        id: entity.id, path: file.path,
        name: entity.title ?? 'photo.jpg',
        sizeBytes: stat.size, createdAt: entity.createDateTime,
        bytes: thumbBytes,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordScanMetadata(DateTime startTime, int count) async {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    await _scanPrefs.setLastScanTime(DateTime.now());
    await _scanPrefs.setLastScanDuration(elapsed);
    await _scanPrefs.setLastScanCount(count);
  }

  Future<List<DuplicateGroup>> findDuplicates() async {
    final assets = await _db.getAllPhotos();
    return DuplicateDetectorService().findDuplicates(assets);
  }

  // ── Batch processing (runs in isolate) ──────────────────────────────────

  /// Only blur detection + perceptual hashing. No classification, no junk,
  /// no low-light, no smart naming.
  static List<_PhotoProcessResult> _processBatch(List<_PhotoData> photos) {
    final results = <_PhotoProcessResult>[];
    for (final photo in photos) {
      try {
        final result = _processOnePhoto(photo);
        if (result != null) results.add(result);
      } catch (_) {}
    }
    return results;
  }

  static _PhotoProcessResult? _processOnePhoto(_PhotoData photo) {
    if (photo.bytes.isEmpty) return null;

    img.Image? image;
    try {
      image = img.decodeImage(photo.bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;

    final issues = <QualityIssue>[];

    // Blur detection — Laplacian variance
    if (MlAnalysisService.isBlurryStatic(image)) {
      issues.add(QualityIssue.blurry);
    }

    // Perceptual hashes for duplicate detection
    final pHash = DuplicateDetectorService.computePHashFromImage(image);
    final dHash = DuplicateDetectorService.computeDHashFromImage(image);

    return _PhotoProcessResult(
      id: photo.id,
      path: photo.path,
      name: photo.name,
      sizeBytes: photo.sizeBytes,
      createdAt: photo.createdAt,
      issues: issues,
      pHash: pHash,
      dHash: dHash,
    );
  }
}
