import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'duplicate_detector_service.dart';
import 'ml_analysis_service.dart';
import 'junk_detector_service.dart';
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

/// Result of processing a single photo in an isolate.
class _PhotoProcessResult {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final PhotoCategory category;
  final List<QualityIssue> issues;
  final String suggestedName;
  final String? pHash;
  final String? dHash;

  const _PhotoProcessResult({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    required this.category,
    required this.issues,
    required this.suggestedName,
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

/// Orchestrates the full scan pipeline with incremental and batch processing.
///
/// Key optimizations:
/// 1. Incremental: skips photos already in DB (by asset ID)
/// 2. Single decode: each photo decoded once, result shared across all analyses
/// 3. Batch isolates: processes chunks in one isolate instead of 4 per photo
/// 4. Chunked DB writes: upserts in batches instead of one giant batch
/// 5. Memory-bounded: small batch size + immediate byte release keeps peak
///    memory under ~30MB regardless of library size
class ScannerService {
  final _db = DatabaseService();
  final _scanPrefs = ScanPreferencesService();

  /// Batch size for isolate processing. 5 photos × ~5MB avg = ~25MB peak.
  /// Smaller than before (was 20) to reduce memory pressure on low-RAM devices.
  static const int _batchSize = 5;

  /// DB write chunk size. Flush every 50 photos to avoid accumulating
  /// PhotoAsset objects in memory.
  static const int _dbChunkSize = 50;

  /// Full scan: discovers all photos, skips already-scanned ones,
  /// processes new photos in batches.
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
      scanned: 0,
      total: 0,
      currentFile: 'Loading photo library...',
      phase: 'loading',
    );

    // Discover all device photos
    var albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) {
      albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
    }
    if (albums.isEmpty) {
      yield const ScanProgress(
          scanned: 0, total: 0, currentFile: 'No photos found', phase: 'done');
      return;
    }

    // Collect all assets, deduplicate by ID
    final seenIds = <String>{};
    final allAssets = <AssetEntity>[];
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      final assets = await album.getAssetListRange(start: 0, end: count);
      for (final asset in assets) {
        if (seenIds.add(asset.id)) {
          allAssets.add(asset);
        }
      }
    }

    final totalOnDevice = allAssets.length;
    if (totalOnDevice == 0) {
      yield const ScanProgress(
          scanned: 0, total: 0, currentFile: 'No photos found', phase: 'done');
      return;
    }

    // --- Incremental: find which photos are new ---
    // Single DB call for both incremental check and prune detection
    List<AssetEntity> toProcess;
    int skippedCount = 0;
    final existingIds = forceFullRescan
        ? <String>[]
        : await _db.getAllPhotoIds();

    if (forceFullRescan) {
      toProcess = allAssets;
    } else {
      final existingSet = existingIds.toSet();
      toProcess = allAssets.where((a) => !existingSet.contains(a.id)).toList();
      skippedCount = totalOnDevice - toProcess.length;
    }

    // --- Prune: remove DB entries for photos no longer on device ---
    if (existingIds.isNotEmpty) {
      final deviceIdSet = seenIds;
      final staleIds =
          existingIds.where((id) => !deviceIdSet.contains(id)).toList();
      if (staleIds.isNotEmpty) {
        await _db.deletePhotos(staleIds);
      }
    }

    if (toProcess.isEmpty) {
      yield ScanProgress(
        scanned: totalOnDevice,
        total: totalOnDevice,
        skipped: skippedCount,
        currentFile: 'All photos already scanned',
        phase: 'done',
      );
      await _recordScanMetadata(startTime, totalOnDevice);
      return;
    }

    yield ScanProgress(
      scanned: 0,
      total: toProcess.length,
      skipped: skippedCount,
      currentFile: 'Starting scan of ${toProcess.length} new photos...',
      phase: 'scanning',
    );

    // --- Process in batches ---
    final pendingResults = <PhotoAsset>[];
    int processed = 0;

    for (int batchStart = 0;
        batchStart < toProcess.length;
        batchStart += _batchSize) {
      final batchEnd = (batchStart + _batchSize).clamp(0, toProcess.length);
      final batchEntities = toProcess.sublist(batchStart, batchEnd);

      // Read photo data one at a time to avoid holding multiple full-res
      // images in memory. Use thumbnail bytes for analysis (all algorithms
      // downsample anyway), full file only for path/size metadata.
      final batchPhotos = <_PhotoData>[];
      for (final entity in batchEntities) {
        try {
          // Get file metadata (path, size) without reading full bytes
          final file = await entity.file;
          if (file == null) continue;
          final stat = await file.stat();

          // Use photo_manager thumbnail (max 1024px) for analysis.
          // This is ~200KB vs 5-10MB for full-res — 25-50× less memory.
          final thumbBytes = await entity.thumbnailDataWithSize(
            const ThumbnailSize(1024, 1024),
            quality: 80,
          );
          if (thumbBytes == null || thumbBytes.isEmpty) continue;

          batchPhotos.add(_PhotoData(
            id: entity.id,
            path: file.path,
            name: entity.title ?? 'photo.jpg',
            sizeBytes: stat.size,
            createdAt: entity.createDateTime,
            bytes: thumbBytes,
          ));
        } catch (_) {
          // Skip unreadable photos
        }
      }

      if (batchPhotos.isEmpty) {
        processed += batchEntities.length;
        continue;
      }

      // Process entire batch in a single isolate.
      // After Isolate.run returns, batchPhotos (and their byte arrays)
      // become eligible for GC since no references are held.
      List<_PhotoProcessResult> results;
      try {
        results =
            await Isolate.run(() => _processBatch(batchPhotos));
      } catch (_) {
        processed += batchEntities.length;
        continue;
      }

      // Convert results to PhotoAsset (lightweight — no image bytes)
      final entityMap = {for (final e in batchEntities) e.id: e};
      for (final r in results) {
        pendingResults.add(PhotoAsset(
          id: r.id,
          path: r.path,
          name: r.name,
          sizeBytes: r.sizeBytes,
          createdAt: r.createdAt,
          category: r.category,
          issues: r.issues,
          suggestedName: r.suggestedName,
          pHash: r.pHash,
          dHash: r.dHash,
          entity: entityMap[r.id],
        ));
      }

      processed += batchEntities.length;

      yield ScanProgress(
        scanned: processed,
        total: toProcess.length,
        skipped: skippedCount,
        currentFile: batchPhotos.last.name,
        phase: 'scanning',
      );

      // Flush to DB frequently to avoid accumulating PhotoAsset objects
      if (pendingResults.length >= _dbChunkSize) {
        await _db.upsertPhotos(pendingResults);
        pendingResults.clear();
      }
    }

    // Write remaining results
    if (pendingResults.isNotEmpty) {
      yield ScanProgress(
        scanned: processed,
        total: toProcess.length,
        skipped: skippedCount,
        currentFile: 'Saving to database...',
        phase: 'saving',
      );
      await _db.upsertPhotos(pendingResults);
    }

    await _recordScanMetadata(startTime, totalOnDevice);

    yield ScanProgress(
      scanned: toProcess.length,
      total: toProcess.length,
      skipped: skippedCount,
      currentFile: 'Done',
      phase: 'done',
    );
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

  /// Processes a batch of photos in a single isolate.
  /// Each photo is decoded once; the decoded image is reused for all analyses.
  static List<_PhotoProcessResult> _processBatch(List<_PhotoData> photos) {
    final results = <_PhotoProcessResult>[];

    for (final photo in photos) {
      try {
        final result = _processOnePhoto(photo);
        if (result != null) results.add(result);
      } catch (_) {
        // Skip photos that fail processing
      }
    }

    return results;
  }

  /// Processes a single photo: decode once, run all analyses on the decoded image.
  static _PhotoProcessResult? _processOnePhoto(_PhotoData photo) {
    if (photo.bytes.isEmpty) return null;

    img.Image? image;
    try {
      image = img.decodeImage(photo.bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;

    // All analyses share this single decoded image
    final issues = <QualityIssue>[];

    // Blur detection
    if (MlAnalysisService.isBlurryStatic(image)) {
      issues.add(QualityIssue.blurry);
    }

    // Low light detection
    if (MlAnalysisService.isLowLightStatic(image)) {
      issues.add(QualityIssue.lowLight);
    }

    // Junk detection (image-based)
    if (MlAnalysisService.looksLikeJunkStatic(image)) {
      issues.add(QualityIssue.junk);
    }

    // Junk detection (filename-based)
    if (!issues.contains(QualityIssue.junk)) {
      if (JunkDetectorService.isJunkByFilenameStatic(photo.name)) {
        issues.add(QualityIssue.junk);
      }
    }

    // Classification — reuse decoded image, skip re-decode
    final category =
        MlAnalysisService.classifyFromImage(image, photo.name);

    // Smart naming
    final suggestedName = MlAnalysisService.buildSmartNameStatic(
      originalName: photo.name,
      category: category,
      createdAt: photo.createdAt,
    );

    // Perceptual hashes — computed from decoded image, no re-decode
    final pHash = DuplicateDetectorService.computePHashFromImage(image);
    final dHash = DuplicateDetectorService.computeDHashFromImage(image);

    return _PhotoProcessResult(
      id: photo.id,
      path: photo.path,
      name: photo.name,
      sizeBytes: photo.sizeBytes,
      createdAt: photo.createdAt,
      category: category,
      issues: issues,
      suggestedName: suggestedName,
      pHash: pHash,
      dHash: dHash,
    );
  }
}
