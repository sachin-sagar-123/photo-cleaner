import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../models/models.dart';
import '../../../../services/services.dart';
import '../../data/photo_dao.dart';
import '../../data/scan_repository.dart';

// ── DAOs, Repository & Services ───────────────────────────────────────────

final photoDaoProvider = Provider((ref) =>
    PhotoDao(ref.read(appDatabaseProvider)));

final scanRepositoryProvider = Provider((ref) =>
    ScanRepository(
      ref.read(photoDaoProvider),
      ref.read(memoryCacheProvider),
    ));

final scannerServiceProvider = Provider((_) => ScannerService());

final scanPreferencesProvider = Provider((_) => ScanPreferencesService());

final backgroundScanProvider = Provider((_) => BackgroundScanService());

// ── Scan State ────────────────────────────────────────────────────────────

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
  }) => ScanState(
    isScanning: isScanning ?? this.isScanning,
    progress: progress == _sentinel ? this.progress : progress as ScanProgress?,
    error: error == _sentinel ? this.error : error as String?,
    lastScanTime: lastScanTime == _sentinel ? this.lastScanTime : lastScanTime as DateTime?,
    lastScanDurationMs: lastScanDurationMs == _sentinel ? this.lastScanDurationMs : lastScanDurationMs as int?,
    lastScanCount: lastScanCount == _sentinel ? this.lastScanCount : lastScanCount as int?,
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
      await for (final progress in _scanner.scan(forceFullRescan: forceFullRescan)) {
        state = state.copyWith(progress: progress);
      }
      // Invalidate cached data after scan completes
      _ref.read(scanRepositoryProvider).invalidate();
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

final scanStateProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref.read(scannerServiceProvider), ref);
});

// ── Photo queries (via cached repository) ─────────────────────────────────

final photosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(photoDaoProvider);
  return dao.getAllPhotos();
});

final photosByCategoryProvider =
    FutureProvider.family<List<PhotoAsset>, PhotoCategory>((ref, cat) async {
  final db = ref.read(databaseServiceProvider);
  return db.getPhotosByCategory(cat);
});

// Legacy bridge — will be removed once all screens use repositories directly
final databaseServiceProvider = Provider((_) => DatabaseService());
