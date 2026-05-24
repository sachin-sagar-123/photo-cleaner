import 'package:photo_manager/photo_manager.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'duplicate_detector_service.dart';
import 'ml_analysis_service.dart';
import 'junk_detector_service.dart';

class ScanProgress {
  final int scanned;
  final int total;
  final String currentFile;

  const ScanProgress({
    required this.scanned,
    required this.total,
    required this.currentFile,
  });

  double get percent => total > 0 ? scanned / total : 0;
}

/// Orchestrates the full scan pipeline: load → hash → classify → analyze → save.
class ScannerService {
  final _db = DatabaseService();
  final _duplicateDetector = DuplicateDetectorService();
  final _mlAnalysis = MlAnalysisService();
  final _junkDetector = JunkDetectorService();

  Stream<ScanProgress> scan() async* {
    final permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    // Accept both full and limited (Android 14 partial) access
    if (!permission.isAuth && !permission.hasAccess) {
      throw Exception(
          'Photo library permission denied. Go to Settings > Apps > PhotoCleaner > Permissions > Photos and videos > Allow all.');
    }

    // Try "All Photos" first, fall back to listing all albums
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
      yield const ScanProgress(scanned: 0, total: 0, currentFile: 'No photos found');
      return;
    }

    // Collect assets from all albums, deduplicate by ID
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

    final total = allAssets.length;
    if (total == 0) {
      yield const ScanProgress(scanned: 0, total: 0, currentFile: 'No photos found');
      return;
    }
    final photoAssets = <PhotoAsset>[];

    for (int i = 0; i < allAssets.length; i++) {
      final entity = allAssets[i];
      yield ScanProgress(
        scanned: i,
        total: total,
        currentFile: entity.title ?? 'Unknown',
      );

      final file = await entity.file;
      if (file == null) continue;

      final bytes = await file.readAsBytes();
      final stat = await file.stat();

      // Compute hashes
      final pHash = await _duplicateDetector.computePHash(bytes);
      final dHash = await _duplicateDetector.computeDHash(bytes);

      // ML analysis
      final issues = await _mlAnalysis.analyzeImage(bytes);
      final junkIssues = _junkDetector.detectJunkIssues(
          bytes, entity.title ?? '');
      final allIssues = {...issues, ...junkIssues}.toList();

      // Classification
      final category = await _mlAnalysis.classifyImage(
          bytes, entity.title ?? '');

      // Smart naming
      final suggestedName = await _mlAnalysis.suggestFilename(
        originalName: entity.title ?? 'photo.jpg',
        category: category,
        createdAt: entity.createDateTime,
      );

      final asset = PhotoAsset(
        id: entity.id,
        path: file.path,
        name: entity.title ?? 'photo.jpg',
        sizeBytes: stat.size,
        createdAt: entity.createDateTime,
        category: category,
        issues: allIssues,
        suggestedName: suggestedName,
        pHash: pHash,
        dHash: dHash,
        entity: entity,
      );

      photoAssets.add(asset);
    }

    // Batch save
    await _db.upsertPhotos(photoAssets);

    yield ScanProgress(
      scanned: total,
      total: total,
      currentFile: 'Done',
    );
  }

  Future<List<DuplicateGroup>> findDuplicates() async {
    final assets = await _db.getAllPhotos();
    return _duplicateDetector.findDuplicates(assets);
  }
}
