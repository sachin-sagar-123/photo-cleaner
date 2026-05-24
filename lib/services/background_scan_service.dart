import 'package:workmanager/workmanager.dart';
import 'scan_preferences_service.dart';

/// Unique task name registered with WorkManager.
const String backgroundScanTaskName = 'com.photocleaner.backgroundScan';

/// Top-level callback for WorkManager. Must be a top-level or static function.
/// This runs in a separate isolate with no Flutter UI — it can only do
/// database and file I/O.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == backgroundScanTaskName) {
      try {
        // Import scanner dynamically to avoid pulling in UI dependencies
        // WorkManager runs in a headless isolate — no widget tree available
        final scanPrefs = ScanPreferencesService();

        // Check if scan is actually due (user may have scanned manually)
        final isDue = await scanPrefs.isScanDue();
        if (!isDue) return true;

        // We cannot run the full ScannerService here because photo_manager
        // requires a running Flutter engine with platform channels.
        // Instead, we mark that a scan is due so the app runs it on next open.
        // This is the standard pattern for media-access background tasks on
        // Android 14+ where background media access is restricted.
        await scanPrefs.setBackgroundScanPending(true);

        return true;
      } catch (_) {
        return false;
      }
    }
    return true;
  });
}

/// Manages registration and cancellation of periodic background scan tasks.
class BackgroundScanService {
  final _scanPrefs = ScanPreferencesService();

  /// Register a periodic background task that runs every [frequencyDays] days.
  /// On Android, WorkManager respects battery optimization and Doze mode.
  Future<void> registerPeriodicScan({int frequencyDays = 7}) async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // Cancel any existing registration before re-registering
    await Workmanager().cancelByUniqueName(backgroundScanTaskName);

    await Workmanager().registerPeriodicTask(
      backgroundScanTaskName,
      backgroundScanTaskName,
      frequency: Duration(days: frequencyDays),
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: true,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );

    await _scanPrefs.setBackgroundScan(true);
    await _scanPrefs.setScanFrequencyDays(frequencyDays);
  }

  /// Cancel the periodic background scan.
  Future<void> cancelPeriodicScan() async {
    await Workmanager().cancelByUniqueName(backgroundScanTaskName);
    await _scanPrefs.setBackgroundScan(false);
  }

  /// Check if a background-triggered scan is pending (set by the background
  /// task when it fires but can't access photos directly).
  Future<bool> isBackgroundScanPending() async {
    return _scanPrefs.getBackgroundScanPending();
  }

  /// Clear the pending flag after the foreground scan completes.
  Future<void> clearPendingScan() async {
    await _scanPrefs.setBackgroundScanPending(false);
  }
}
