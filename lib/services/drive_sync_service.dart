import 'dart:isolate';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'database_service.dart';

// Progress event emitted during Drive scan
class DriveScanProgress {
  final int scanned;
  final int total;
  final String currentFile;
  final String phase; // 'listing' | 'analyzing'

  const DriveScanProgress({
    required this.scanned,
    required this.total,
    required this.currentFile,
    required this.phase,
  });

  double get percent => total > 0 ? scanned / total : 0;
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;
  _AuthClient(this._headers, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class DriveSyncService {
  static final _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveScope, // full access — needed for delete
    ],
  );

  final _db = DatabaseService();
  final _uuid = const Uuid();

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  http.Client? _httpClient;

  bool get isSignedIn => _currentUser != null;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;
      await _initDriveApi();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _httpClient?.close();
    _httpClient = null;
  }

  Future<void> _initDriveApi() async {
    if (_currentUser == null) return;
    // Re-fetch authentication to get a fresh (or refreshed) access token
    final auth = await _currentUser!.authentication;
    _httpClient?.close();
    _httpClient = http.Client();
    final client = _AuthClient(
      {'Authorization': 'Bearer ${auth.accessToken}'},
      _httpClient!,
    );
    _driveApi = drive.DriveApi(client);
  }

  /// Re-initializes the Drive API client to refresh the OAuth token.
  /// Called before every public operation to avoid stale 1-hour tokens.
  Future<void> _ensureAuth() async {
    await _initDriveApi();
  }

  // ── Drive Scan Pipeline ───────────────────────────────────────────────────

  /// Full Drive analysis:
  /// 1. List all Drive image files (metadata only — no download)
  /// 2. Fetch MD5 checksums and compare against local photos
  /// 3. Fetch thumbnails (~10 KB each) for blur/junk analysis
  /// 4. Save results to DB
  Stream<DriveScanProgress> scanDrive() async* {
    await _ensureAuth();
    if (_driveApi == null) return;

    // Phase 1: list all Drive image files with metadata
    yield const DriveScanProgress(
        scanned: 0, total: 0, currentFile: 'Listing Drive files...', phase: 'listing');

    final driveFiles = await _listAllDriveImages();
    final total = driveFiles.length;

    if (total == 0) {
      yield const DriveScanProgress(
          scanned: 0, total: 0, currentFile: 'No images found', phase: 'listing');
      return;
    }

    // Load local MD5s for exact-duplicate matching
    final localPhotos = await _db.getAllPhotos();
    final localMd5Map = <String, PhotoAsset>{};
    for (final p in localPhotos) {
      final md5 = p.driveMd5;
      if (md5 != null) localMd5Map[md5] = p;
    }

    // Phase 2: analyze each Drive file
    final driveAssets = <PhotoAsset>[];

    for (int i = 0; i < driveFiles.length; i++) {
      final f = driveFiles[i];
      final name = f.name ?? 'unknown';

      yield DriveScanProgress(
        scanned: i,
        total: total,
        currentFile: name,
        phase: 'analyzing',
      );

      final md5 = f.md5Checksum;
      final sizeBytes = int.tryParse(f.size ?? '0') ?? 0;
      final createdAt = f.createdTime ?? DateTime.now();

      // Check if this Drive file is already local (exact MD5 match)
      final isAlreadyLocal = md5 != null && localMd5Map.containsKey(md5);

      // Fetch thumbnail for blur/junk analysis (only if not already local)
      List<QualityIssue> issues = [];
      if (!isAlreadyLocal && f.thumbnailLink != null) {
        issues = await _analyzeThumbnail(f.thumbnailLink!, name);
      }

      // Mark local copy as backed-up if MD5 matches
      if (isAlreadyLocal) {
        final local = localMd5Map[md5]!;
        await _db.upsertPhoto(local.copyWith(
          isBackedUp: true,
          driveFileId: f.id,
          driveMd5: md5,
        ));
      }

      final asset = PhotoAsset(
        id: 'drive_${f.id ?? _uuid.v4()}',
        path: '', // Drive-only — no local path
        name: name,
        sizeBytes: sizeBytes,
        createdAt: createdAt,
        issues: issues,
        isBackedUp: true,
        driveFileId: f.id,
        driveMd5: md5,
        isDriveOnly: !isAlreadyLocal,
      );

      driveAssets.add(asset);
    }

    // Batch save Drive assets
    await _db.upsertPhotos(driveAssets);

    yield DriveScanProgress(
      scanned: total,
      total: total,
      currentFile: 'Done',
      phase: 'analyzing',
    );
  }

  // ── Drive File Listing ────────────────────────────────────────────────────

  /// Lists all image files from Drive with metadata only — no file content downloaded.
  Future<List<drive.File>> _listAllDriveImages() async {
    final files = <drive.File>[];
    String? pageToken;

    do {
      final result = await _driveApi!.files.list(
        spaces: 'drive',
        q: "mimeType contains 'image/' and trashed = false",
        // Request only the fields we need — keeps response small
        $fields:
            'nextPageToken, files(id, name, size, md5Checksum, createdTime, thumbnailLink, imageMediaMetadata)',
        pageToken: pageToken,
        pageSize: 1000,
      );
      files.addAll(result.files ?? []);
      pageToken = result.nextPageToken;
    } while (pageToken != null);

    return files;
  }

  // ── Thumbnail Analysis ────────────────────────────────────────────────────

  /// Downloads thumbnail (~10 KB) and runs blur + junk detection.
  Future<List<QualityIssue>> _analyzeThumbnail(
      String thumbnailUrl, String filename) async {
    try {
      final response = await http.get(Uri.parse(thumbnailUrl));
      if (response.statusCode != 200) return [];
      final bytes = response.bodyBytes;
      return await Isolate.run(() => _analyzeBytes(bytes, filename));
    } catch (_) {
      return [];
    }
  }

  static List<QualityIssue> _analyzeBytes(Uint8List bytes, String filename) {
    final issues = <QualityIssue>[];
    final image = img.decodeImage(bytes);
    if (image == null) return issues;

    // Blur detection via Laplacian variance
    final gray = img.grayscale(image);
    double sum = 0, sumSq = 0;
    int count = 0;
    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final c = img.getLuminance(gray.getPixel(x, y));
        final t = img.getLuminance(gray.getPixel(x, y - 1));
        final b = img.getLuminance(gray.getPixel(x, y + 1));
        final l = img.getLuminance(gray.getPixel(x - 1, y));
        final r = img.getLuminance(gray.getPixel(x + 1, y));
        final lap = (4 * c - t - b - l - r).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }
    if (count > 0) {
      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);
      if (variance < 100.0) issues.add(QualityIssue.blurry);
    }

    // Junk detection: filename patterns
    final lower = filename.toLowerCase();
    const junkPatterns = ['whatsapp', 'forward', 'meme', 'viral', 'received'];
    if (junkPatterns.any((p) => lower.contains(p))) {
      issues.add(QualityIssue.junk);
    }

    // Junk detection: edge density (text-heavy images)
    int edgeCount = 0;
    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final c = img.getLuminance(gray.getPixel(x, y));
        final r = img.getLuminance(gray.getPixel(x + 1, y));
        final bv = img.getLuminance(gray.getPixel(x, y + 1));
        if ((c - r).abs() > 80 || (c - bv).abs() > 80) edgeCount++;
      }
    }
    final edgeRatio = edgeCount / (gray.width * gray.height);
    if (edgeRatio > 0.25) issues.add(QualityIssue.junk);

    return issues;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Permanently deletes a file from Google Drive by its Drive file ID.
  Future<bool> deleteFromDrive(String driveFileId) async {
    await _ensureAuth();
    if (_driveApi == null) return false;
    try {
      await _driveApi!.files.delete(driveFileId);
      await _db.deletePhoto('drive_$driveFileId');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Batch delete multiple Drive files.
  Future<int> deleteBatchFromDrive(
    List<String> driveFileIds, {
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensureAuth();
    if (_driveApi == null) return 0;
    int deleted = 0;
    for (int i = 0; i < driveFileIds.length; i++) {
      final ok = await deleteFromDrive(driveFileIds[i]);
      if (ok) deleted++;
      onProgress?.call(i + 1, driveFileIds.length);
    }
    return deleted;
  }

  // ── Legacy helpers (kept for Settings screen) ─────────────────────────────

  Future<Set<String>> getBackedUpFilenames() async {
    final files = await _listAllDriveImages();
    return files.map((f) => f.name ?? '').where((n) => n.isNotEmpty).toSet();
  }
}
