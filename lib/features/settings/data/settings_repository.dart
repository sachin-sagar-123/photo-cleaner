import 'package:shared_preferences/shared_preferences.dart';

/// Typed wrapper around SharedPreferences for app settings.
class SettingsRepository {
  Future<bool> getAutoScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_scan') ?? false;
  }

  Future<void> setAutoScan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_scan', value);
  }

  Future<bool> getBackgroundScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('background_scan') ?? false;
  }

  Future<void> setBackgroundScan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_scan', value);
  }

  Future<int> getScanFrequencyDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('scan_frequency_days') ?? 7;
  }

  Future<void> setScanFrequencyDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scan_frequency_days', days);
  }
}
