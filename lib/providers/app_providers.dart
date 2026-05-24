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
final scanPreferencesProvider = Provider((_) => ScanPreferencesService());
final backgroundScanProvider = Provider((_) => BackgroundScanService());
final importantServiceProvider = Provider((_) => ImportantService());
final aiServiceProvider = Provider((_) => AIService());
final aiCategorizerProvider = Provider((ref) =>
    AICategorizer(ref.read(aiServiceProvider), ref.read(databaseServiceProvider)));

/// State for AI batch categorization progress.
class AICategorizeState {
  final bool isRunning;
  final AICategorizeProgress? progress;
  final String? error;

  const AICategorizeState({
    this.isRunning = false,
    this.progress,
    this.error,
  });
}

class AICategorizeNotifier extends StateNotifier<AICategorizeState> {
  final AICategorizer _categorizer;
  final Ref _ref;

  AICategorizeNotifier(this._categorizer, this._ref)
      : super(const AICategorizeState());

  Future<void> start({bool recategorize = false}) async {
    if (state.isRunning) return;
    state = const AICategorizeState(isRunning: true);

    try {
      final stream = recategorize
          ? _categorizer.recategorizeAll()
          : _categorizer.categorizeAll();

      await for (final progress in stream) {
        state = AICategorizeState(
          isRunning: !progress.isDone,
          progress: progress,
        );
      }

      // Invalidate category-dependent providers
      for (final cat in PhotoCategory.values) {
        _ref.invalidate(photosCountByCategoryProvider(cat));
        _ref.invalidate(photosByCategoryProvider(cat));
      }
      _ref.invalidate(storageStatsProvider);
    } catch (e) {
      state = AICategorizeState(isRunning: false, error: e.toString());
    }
  }

  void cancel() {
    _categorizer.cancel();
  }
}

final aiCategorizeStateProvider =
    StateNotifierProvider<AICategorizeNotifier, AICategorizeState>((ref) {
  return AICategorizeNotifier(
    ref.read(aiCategorizerProvider),
    ref,
  );
});

final importantPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getImportantPhotos();
});

final importantCountProvider = FutureProvider<int>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getImportantCount();
});

// ── Scan State ────────────────────────────────────────────────────────────

/// Sentinel used by copyWith to distinguish "not passed" from "explicitly null".
const _sentinel = Object();

class ScanState {
  final bool isScanning;
  final ScanProgress? progress;
  final String? error;
  final DateTime? lastScanTime;
  final int? lastScanDurationMs;
  final int? lastScanCount;

  const ScanState({
    this.isScanning = false,
    this.progress,
    this.error,
    this.lastScanTime,
    this.lastScanDurationMs,
    this.lastScanCount,
  });

  /// [error] and [progress] accept explicit null to clear the field.
  /// Pass nothing (omit the parameter) to keep the current value.
  ScanState copyWith({
    bool? isScanning,
    Object? progress = _sentinel,
    Object? error = _sentinel,
    Object? lastScanTime = _sentinel,
    Object? lastScanDurationMs = _sentinel,
    Object? lastScanCount = _sentinel,
  }) =>
      ScanState(
        isScanning: isScanning ?? this.isScanning,
        progress: progress == _sentinel
            ? this.progress
            : progress as ScanProgress?,
        error: error == _sentinel ? this.error : error as String?,
        lastScanTime: lastScanTime == _sentinel
            ? this.lastScanTime
            : lastScanTime as DateTime?,
        lastScanDurationMs: lastScanDurationMs == _sentinel
            ? this.lastScanDurationMs
            : lastScanDurationMs as int?,
        lastScanCount: lastScanCount == _sentinel
            ? this.lastScanCount
            : lastScanCount as int?,
      );
}

class ScanNotifier extends StateNotifier<ScanState> {
  final ScannerService _scanner;
  final Ref _ref;

  ScanNotifier(this._scanner, this._ref) : super(const ScanState()) {
    // Load persisted scan metadata on creation
    _loadScanMetadata();
  }

  Future<void> _loadScanMetadata() async {
    final prefs = _ref.read(scanPreferencesProvider);
    final lastTime = await prefs.getLastScanTime();
    final lastDuration = await prefs.getLastScanDuration();
    final lastCount = await prefs.getLastScanCount();
    state = state.copyWith(
      lastScanTime: lastTime,
      lastScanDurationMs: lastDuration,
      lastScanCount: lastCount,
    );
  }

  /// Start an incremental scan (only new photos).
  Future<void> startScan() async => _runScan(forceFullRescan: false);

  /// Force a full re-scan of all photos.
  Future<void> startFullRescan() async => _runScan(forceFullRescan: true);

  Future<void> _runScan({required bool forceFullRescan}) async {
    state = state.copyWith(isScanning: true, error: null, progress: null);
    try {
      await for (final progress
          in _scanner.scan(forceFullRescan: forceFullRescan)) {
        state = state.copyWith(progress: progress);
      }
      // Invalidate dependent providers so UI reflects newly scanned data
      _ref.invalidate(storageStatsProvider);
      _ref.invalidate(duplicatesProvider);
      _ref.invalidate(unreviewedCountProvider);
      _ref.invalidate(junkPhotosProvider);
      _ref.invalidate(blurryPhotosProvider);
      _ref.invalidate(backedUpCleanupProvider);

      // Reload persisted metadata
      await _loadScanMetadata();

      // Clear background scan pending flag if set
      final bgService = _ref.read(backgroundScanProvider);
      await bgService.clearPendingScan();

      // Auto-trigger AI categorization if AI is configured
      final ai = _ref.read(aiServiceProvider);
      await ai.load();
      if (ai.isConfigured) {
        _ref.read(aiCategorizeStateProvider.notifier).start();
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
  return ScanNotifier(ref.read(scannerServiceProvider), ref);
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

/// Count-only provider for category badges on dashboard — avoids loading
/// all PhotoAsset objects just to show a number.
final photosCountByCategoryProvider =
    FutureProvider.family<int, PhotoCategory>((ref, cat) async {
  final db = ref.read(databaseServiceProvider);
  return db.getPhotosCountByCategory(cat);
});

final unreviewedPhotosProvider =
    FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getUnreviewedPhotos();
});

/// Count-only provider for dashboard badge — avoids loading all unreviewed
/// PhotoAsset objects just to show a number.
final unreviewedCountProvider = FutureProvider<int>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getUnreviewedCount();
});

// ── Issue-filtered providers for cleanup screen ───────────────────────────

final junkPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getPhotosByIssue(QualityIssue.junk);
});

final blurryPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getPhotosByIssue(QualityIssue.blurry);
});

final backedUpCleanupProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getBackedUpPhotosForCleanup();
});

// ── Duplicates ────────────────────────────────────────────────────────────

final duplicatesProvider =
    FutureProvider<List<DuplicateGroup>>((ref) async {
  final scanner = ref.read(scannerServiceProvider);
  return scanner.findDuplicates();
});

// ── Storage Stats ─────────────────────────────────────────────────────────

/// Storage stats computed via SQL aggregates — no PhotoAsset objects loaded.
/// For 16K photos this uses ~0 bytes of Dart heap vs ~50MB before.
final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final agg = await db.getStorageAggregates();

  // 64 GB as explicit literal to avoid int overflow from 64*1024*1024*1024
  const totalBytes = 68719476736;

  return StorageStats(
    totalBytes: totalBytes,
    usedBytes: agg['total_bytes']!,
    photoBytes: agg['total_bytes']!,
    duplicateBytes: agg['duplicate_bytes']!,
    junkBytes: agg['junk_bytes']!,
    backedUpBytes: agg['backed_up_bytes']!,
    totalPhotos: agg['total_photos']!,
    duplicateCount: agg['duplicate_count']!,
    junkCount: agg['junk_count']!,
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

  /// [error] and [progress] accept explicit null to clear the field.
  DriveScanState copyWith({
    bool? isScanning,
    Object? progress = _sentinel,
    Object? error = _sentinel,
    bool? completed,
  }) =>
      DriveScanState(
        isScanning: isScanning ?? this.isScanning,
        progress: progress == _sentinel
            ? this.progress
            : progress as DriveScanProgress?,
        error: error == _sentinel ? this.error : error as String?,
        completed: completed ?? this.completed,
      );
}

class DriveScanNotifier extends StateNotifier<DriveScanState> {
  final DriveSyncService _drive;
  final Ref? _ref;

  DriveScanNotifier(this._drive, this._ref)
      : super(const DriveScanState());

  Future<void> startScan() async {
    state = state.copyWith(
        isScanning: true, error: null, progress: null, completed: false);
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
final backgroundScanEnabledProvider = StateProvider<bool>((_) => false);
final scanFrequencyDaysProvider = StateProvider<int>((_) => 7);
final defaultCompressionModeProvider =
    StateProvider<CompressionMode>((_) => CompressionMode.smart);

/// Provider that loads persisted scan settings. Read once on app start.
final scanSettingsInitProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(scanPreferencesProvider);
  ref.read(autoScanProvider.notifier).state = await prefs.getAutoScan();
  ref.read(backgroundScanEnabledProvider.notifier).state =
      await prefs.getBackgroundScan();
  ref.read(scanFrequencyDaysProvider.notifier).state =
      await prefs.getScanFrequencyDays();
});
