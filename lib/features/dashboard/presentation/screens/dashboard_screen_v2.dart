import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../../../screens/ai/ai_chat_screen.dart';
import '../../../../screens/drive/drive_screen.dart';
import '../../../../screens/vault/vault_screen.dart';
import '../../../scan/presentation/providers/scan_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/scan_section.dart';
import '../widgets/review_card.dart';
import '../widgets/storage_overview.dart';
import '../widgets/category_grid.dart';
import '../widgets/important_card.dart';
import '../widgets/quick_access_card.dart';

/// Dashboard screen — ~80 lines. All widgets are extracted.
class DashboardScreenV2 extends ConsumerStatefulWidget {
  const DashboardScreenV2({super.key});

  @override
  ConsumerState<DashboardScreenV2> createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends ConsumerState<DashboardScreenV2> {
  bool _autoScanTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initScan());
  }

  Future<void> _initScan() async {
    final prefs = ref.read(scanPreferencesProvider);
    final autoScan = await prefs.getAutoScan();
    ref.read(autoScanProvider.notifier).state = autoScan;
    ref.read(backgroundScanEnabledProvider.notifier).state =
        await prefs.getBackgroundScan();
    ref.read(scanFrequencyDaysProvider.notifier).state =
        await prefs.getScanFrequencyDays();

    if (!mounted || _autoScanTriggered) return;

    final bgPending = await ref.read(backgroundScanProvider).isBackgroundScanPending();
    if (!mounted) return;

    if (bgPending || autoScan) {
      _autoScanTriggered = true;
      ref.read(scanStateProvider.notifier).startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(storageStatsProvider);
    final scanState = ref.watch(scanStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoCleaner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tips_and_updates_outlined),
            tooltip: 'Tips',
            onPressed: () => _showTips(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AIChatScreen())),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(storageStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScanSection(scanState: scanState, ref: ref),
              const SizedBox(height: 16),
              const ReviewCard(),
              const SizedBox(height: 24),
              statsAsync.when(
                data: (stats) => StorageOverview(stats: stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e',
                    style: const TextStyle(color: AppTheme.error)),
              ),
              const SizedBox(height: 24),
              const Text('Quick Access', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: QuickAccessCard(
                  icon: Icons.cloud_outlined, label: 'Drive', color: Colors.blue,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DriveScreen())),
                )),
                const SizedBox(width: 12),
                Expanded(child: QuickAccessCard(
                  icon: Icons.lock_outline, label: 'Vault', color: Colors.amber,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const VaultScreen())),
                )),
              ]),
              const SizedBox(height: 12),
              const ImportantCard(),
              const SizedBox(height: 24),
              const Text('Browse by Category', style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const CategoryGrid(),
            ],
          ),
        ),
      ),
    );
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tips', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _tip(Icons.search, 'Scan photos to find junk, duplicates, and blurry images'),
            _tip(Icons.swipe, 'Use Photo Review to quickly swipe through all photos'),
            _tip(Icons.auto_awesome, 'Create collages from your best photos'),
            _tip(Icons.lock_outline, 'Store important documents in the secure Vault'),
            _tip(Icons.cloud_outlined, 'Connect Google Drive to find cloud duplicates'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tip(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, color: AppTheme.primary, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
    ]),
  );
}
