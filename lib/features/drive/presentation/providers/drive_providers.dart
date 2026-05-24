import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../models/photo_asset.dart';
import '../../../../services/services.dart';
import '../../data/drive_dao.dart';

export '../../../../services/drive_sync_service.dart' show DriveScanProgress;

final driveDaoProvider = Provider((ref) =>
    DriveDao(ref.read(appDatabaseProvider)));

final driveSyncServiceProvider = Provider((_) => DriveSyncService());

final driveSignedInProvider = StateProvider<bool>((_) => false);

// ── Drive Scan State ──────────────────────────────────────────────────────

const _sentinel = Object();

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
    Object? progress = _sentinel,
    Object? error = _sentinel,
    bool? completed,
  }) => DriveScanState(
    isScanning: isScanning ?? this.isScanning,
    progress: progress == _sentinel ? this.progress : progress as DriveScanProgress?,
    error: error == _sentinel ? this.error : error as String?,
    completed: completed ?? this.completed,
  );
}

class DriveScanNotifier extends StateNotifier<DriveScanState> {
  final DriveSyncService _drive;
  final Ref? _ref;

  DriveScanNotifier(this._drive, this._ref) : super(const DriveScanState());

  Future<void> startScan() async {
    state = state.copyWith(
        isScanning: true, error: null, progress: null, completed: false);
    try {
      await for (final progress in _drive.scanDrive()) {
        state = state.copyWith(progress: progress);
      }
      _ref?.invalidate(drivePhotosProvider);
      _ref?.invalidate(driveDuplicatesProvider);
      state = state.copyWith(isScanning: false, completed: true);
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }
}

final driveScanStateProvider =
    StateNotifierProvider<DriveScanNotifier, DriveScanState>((ref) {
  return DriveScanNotifier(ref.read(driveSyncServiceProvider), ref);
});

// ── Drive photo providers ─────────────────────────────────────────────────

final drivePhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(driveDaoProvider);
  return dao.getDrivePhotos();
});

final driveOnlyPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(driveDaoProvider);
  return dao.getDriveOnlyPhotos();
});

final driveDuplicatesProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(driveDaoProvider);
  return dao.getLocalDriveDuplicates();
});

final driveBlurryProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(driveDaoProvider);
  final all = await dao.getDrivePhotos();
  return all.where((p) => p.isBlurry).toList();
});

final driveJunkProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(driveDaoProvider);
  final all = await dao.getDrivePhotos();
  return all.where((p) => p.isJunk).toList();
});
