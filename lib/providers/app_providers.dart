import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
// ignore: unused_import — DriveScanProgress is used in DriveScanState
export '../services/drive_sync_service.dart' show DriveScanProgress;

// ── Services ──────────────────────────────────────────────────────────────

final databaseServiceProvider = Provider((_) => DatabaseService());
final scannerServiceProvider = Provider((_) => ScannerService());
final compressionServiceProvider = Provider((_) => CompressionService());
final driveSyncServiceProvider = Provider((_) => DriveSyncService());
final vaultServiceProvider = Provider((_) => DocumentVaultService());

// ── Scan State ────────────────────────────────────────────────────────────

class ScanState {
  final bool isScanning;
  final ScanProgress? progress;
  final String? error;

  const ScanState({
    this.isScanning = false,
    this.progress,
    this.error,
  });

  ScanState copyWith({
    bool? isScanning,
    ScanProgress? progress,
    String? error,
  }) =>
      ScanState(
        isScanning: isScanning ?? this.isScanning,
        progress: progress ?? this.progress,
        error: error ?? this.error,
      );
}

class ScanNotifier extends StateNotifier<ScanState> {
  final ScannerService _scanner;

  ScanNotifier(this._scanner) : super(const ScanState());

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      await for (final progress in _scanner.scan()) {
        state = state.copyWith(progress: progress);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isScanning: false);
    }
  }
}

final scanStateProvider =
    StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref.read(scannerServiceProvider));
});

// ── Photos ────────────────────────────────────────────────────────────────

final photosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getAllPhotos();
});

final photosByCategoryProvider =
    FutureProvider.family<List<PhotoAsset>, PhotoCategory>((ref, cat) async {
  final db = ref.read(databaseServiceProvider);
  return db.getPhotosByCategory(cat);
});

// ── Duplicates ────────────────────────────────────────────────────────────

final duplicatesProvider =
    FutureProvider<List<DuplicateGroup>>((ref) async {
  final scanner = ref.read(scannerServiceProvider);
  return scanner.findDuplicates();
});

// ── Storage Stats ─────────────────────────────────────────────────────────

final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final photos = await db.getAllPhotos();

  int photoBytes = 0;
  int duplicateBytes = 0;
  int junkBytes = 0;
  int backedUpBytes = 0;
  int duplicateCount = 0;
  int junkCount = 0;

  for (final p in photos) {
    photoBytes += p.sizeBytes;
    if (p.isDuplicate) {
      duplicateBytes += p.sizeBytes;
      duplicateCount++;
    }
    if (p.issues.contains(QualityIssue.junk)) {
      junkBytes += p.sizeBytes;
      junkCount++;
    }
    if (p.isBackedUp) backedUpBytes += p.sizeBytes;
  }

  // Approximate device storage (64 GB default if unavailable)
  const totalBytes = 64 * 1024 * 1024 * 1024;

  return StorageStats(
    totalBytes: totalBytes,
    usedBytes: photoBytes,
    photoBytes: photoBytes,
    duplicateBytes: duplicateBytes,
    junkBytes: junkBytes,
    backedUpBytes: backedUpBytes,
    totalPhotos: photos.length,
    duplicateCount: duplicateCount,
    junkCount: junkCount,
  );
});

// ── Vault ─────────────────────────────────────────────────────────────────

final vaultUnlockedProvider = StateProvider<bool>((_) => false);

final vaultDocumentsProvider =
    FutureProvider<List<VaultDocument>>((ref) async {
  final vault = ref.read(vaultServiceProvider);
  return vault.getAllDocuments();
});

// ── Drive Sync ────────────────────────────────────────────────────────────

final driveSignedInProvider = StateProvider<bool>((_) => false);

// Drive scan state
class DriveScanState {
  final bool isScanning;
  final DriveScanProgress? progress;
  final String? error;
  final bool completed;

  const DriveScanState({
    this.isScanning = false,
    this.progress,
    this.error,
    this.completed = false,
  });

  DriveScanState copyWith({
    bool? isScanning,
    DriveScanProgress? progress,
    String? error,
    bool? completed,
  }) =>
      DriveScanState(
        isScanning: isScanning ?? this.isScanning,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        completed: completed ?? this.completed,
      );
}

class DriveScanNotifier extends StateNotifier<DriveScanState> {
  final DriveSyncService _drive;
  final Ref? _ref;

  DriveScanNotifier(this._drive, this._ref)
      : super(const DriveScanState());

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, error: null, completed: false);
    try {
      await for (final progress in _drive.scanDrive()) {
        state = state.copyWith(progress: progress);
      }
      // Invalidate dependent providers after scan completes
      _ref?.invalidate(drivePhotosProvider);
      _ref?.invalidate(driveDuplicatesProvider);
      _ref?.invalidate(storageStatsProvider);
      state = state.copyWith(isScanning: false, completed: true);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }
}

final driveScanStateProvider =
    StateNotifierProvider<DriveScanNotifier, DriveScanState>((ref) {
  return DriveScanNotifier(
      ref.read(driveSyncServiceProvider), ref);
});

// Drive photo providers
final drivePhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getDrivePhotos();
});

final driveOnlyPhotosProvider =
    FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getDriveOnlyPhotos();
});

final driveDuplicatesProvider =
    FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getLocalDriveDuplicates();
});

final driveBlurryProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final all = await db.getDrivePhotos();
  return all.where((p) => p.isBlurry).toList();
});

final driveJunkProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final all = await db.getDrivePhotos();
  return all.where((p) => p.isJunk).toList();
});

// ── Settings ──────────────────────────────────────────────────────────────

final biometricEnabledProvider = StateProvider<bool>((_) => true);
final autoScanProvider = StateProvider<bool>((_) => false);
final defaultCompressionModeProvider =
    StateProvider<CompressionMode>((_) => CompressionMode.smart);
