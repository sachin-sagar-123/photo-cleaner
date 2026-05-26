import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ── Services ──────────────────────────────────────────────────────────────

final databaseServiceProvider = Provider((_) => DatabaseService());
final scannerServiceProvider = Provider((_) => ScannerService());
final compressionServiceProvider = Provider((_) => CompressionService());
final scanPreferencesProvider = Provider((_) => ScanPreferencesService());
final backgroundScanProvider = Provider((_) => BackgroundScanService());
final importantServiceProvider = Provider((_) => ImportantService());

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

  Future<void> startScan() async => _runScan(forceFullRescan: false);
  Future<void> startFullRescan() async => _runScan(forceFullRescan: true);

  Future<void> _runScan({required bool forceFullRescan}) async {
    state = state.copyWith(isScanning: true, error: null, progress: null);
    try {
      await for (final progress
          in _scanner.scan(forceFullRescan: forceFullRescan)) {
        state = state.copyWith(progress: progress);
      }
      _ref.invalidate(storageStatsProvider);
      _ref.invalidate(duplicatesProvider);
      _ref.invalidate(blurryPhotosProvider);
      _ref.invalidate(importantPhotosProvider);
      _ref.invalidate(importantCountProvider);

      await _loadScanMetadata();

      final bgService = _ref.read(backgroundScanProvider);
      await bgService.clearPendingScan();
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

// ── Cleanup: Blurry ───────────────────────────────────────────────────────

final blurryPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getPhotosByIssue(QualityIssue.blurry);
});

// ── Cleanup: Duplicates ───────────────────────────────────────────────────

final duplicatesProvider =
    FutureProvider<List<DuplicateGroup>>((ref) async {
  final scanner = ref.read(scannerServiceProvider);
  return scanner.findDuplicates();
});

// ── Important ─────────────────────────────────────────────────────────────

final importantPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getImportantPhotos();
});

final importantCountProvider = FutureProvider<int>((ref) async {
  final db = ref.read(databaseServiceProvider);
  return db.getImportantCount();
});

// ── Storage Stats ─────────────────────────────────────────────────────────

final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final db = ref.read(databaseServiceProvider);
  final agg = await db.getStorageAggregates();

  const totalBytes = 68719476736; // 64 GB

  return StorageStats(
    totalBytes: totalBytes,
    usedBytes: agg['total_bytes']!,
    photoBytes: agg['total_bytes']!,
    duplicateBytes: agg['duplicate_bytes']!,
    backedUpBytes: agg['backed_up_bytes']!,
    totalPhotos: agg['total_photos']!,
    duplicateCount: agg['duplicate_count']!,
  );
});

// ── Settings ──────────────────────────────────────────────────────────────

final autoScanProvider = StateProvider<bool>((_) => false);
final backgroundScanEnabledProvider = StateProvider<bool>((_) => false);
final scanFrequencyDaysProvider = StateProvider<int>((_) => 7);
final defaultCompressionModeProvider =
    StateProvider<CompressionMode>((_) => CompressionMode.smart);

final scanSettingsInitProvider = FutureProvider<void>((ref) async {
  final prefs = ref.read(scanPreferencesProvider);
  ref.read(autoScanProvider.notifier).state = await prefs.getAutoScan();
  ref.read(backgroundScanEnabledProvider.notifier).state =
      await prefs.getBackgroundScan();
  ref.read(scanFrequencyDaysProvider.notifier).state =
      await prefs.getScanFrequencyDays();
});
