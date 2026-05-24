import 'package:shared_preferences/shared_preferences.dart';

/// Persists scan-related settings and timestamps.
class ScanPreferencesService {
  static const _keyLastScanTime = 'last_scan_time';
  static const _keyLastScanDuration = 'last_scan_duration_ms';
  static const _keyLastScanCount = 'last_scan_count';
  static const _keyAutoScan = 'auto_scan_enabled';
  static const _keyBackgroundScan = 'background_scan_enabled';
  static const _keyScanFrequencyDays = 'scan_frequency_days';

  Future<DateTime?> getLastScanTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_keyLastScanTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> setLastScanTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastScanTime, time.millisecondsSinceEpoch);
  }

  Future<int?> getLastScanDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastScanDuration);
  }

  Future<void> setLastScanDuration(int durationMs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastScanDuration, durationMs);
  }

  Future<int?> getLastScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastScanCount);
  }

  Future<void> setLastScanCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastScanCount, count);
  }

  Future<bool> getAutoScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoScan) ?? false;
  }

  Future<void> setAutoScan(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoScan, enabled);
  }

  Future<bool> getBackgroundScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundScan) ?? false;
  }

  Future<void> setBackgroundScan(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundScan, enabled);
  }

  Future<int> getScanFrequencyDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyScanFrequencyDays) ?? 7;
  }

  Future<void> setScanFrequencyDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyScanFrequencyDays, days);
  }

  /// Whether a background scan is due based on last scan time and frequency.
  Future<bool> isScanDue() async {
    final lastScan = await getLastScanTime();
    if (lastScan == null) return true;
    final freq = await getScanFrequencyDays();
    return DateTime.now().difference(lastScan).inDays >= freq;
  }

  // ── Background scan pending flag ────────────────────────────────────────
  static const _keyBackgroundScanPending = 'background_scan_pending';

  Future<bool> getBackgroundScanPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBackgroundScanPending) ?? false;
  }

  Future<void> setBackgroundScanPending(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBackgroundScanPending, pending);
  }
}
