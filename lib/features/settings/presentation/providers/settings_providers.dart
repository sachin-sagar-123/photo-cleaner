import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/models.dart';
import '../../data/settings_repository.dart';

final settingsRepoProvider = Provider((_) => SettingsRepository());

final biometricEnabledProvider = StateProvider<bool>((_) => true);
final autoScanProvider = StateProvider<bool>((_) => false);
final backgroundScanEnabledProvider = StateProvider<bool>((_) => false);
final scanFrequencyDaysProvider = StateProvider<int>((_) => 7);
final defaultCompressionModeProvider =
    StateProvider<CompressionMode>((_) => CompressionMode.smart);

/// Loads persisted scan settings on app start.
final scanSettingsInitProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(settingsRepoProvider);
  ref.read(autoScanProvider.notifier).state = await repo.getAutoScan();
  ref.read(backgroundScanEnabledProvider.notifier).state =
      await repo.getBackgroundScan();
  ref.read(scanFrequencyDaysProvider.notifier).state =
      await repo.getScanFrequencyDays();
});
