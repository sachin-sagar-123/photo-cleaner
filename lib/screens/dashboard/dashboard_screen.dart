import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/storage_ring.dart';
import '../../widgets/stat_card.dart';
import '../browser/photo_browser_screen.dart';
import '../category/category_photos_screen.dart';
import '../drive/drive_screen.dart';
import '../important/important_photos_screen.dart';
import '../ai/ai_chat_screen.dart';
import '../vault/vault_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _autoScanTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load persisted settings and wait for completion before reading them
      final prefs = ref.read(scanPreferencesProvider);
      final autoScan = await prefs.getAutoScan();
      ref.read(autoScanProvider.notifier).state = autoScan;
      ref.read(backgroundScanEnabledProvider.notifier).state =
          await prefs.getBackgroundScan();
      ref.read(scanFrequencyDaysProvider.notifier).state =
          await prefs.getScanFrequencyDays();

      if (!mounted) return;
      final scanState = ref.read(scanStateProvider);
      if (scanState.isScanning || _autoScanTriggered) return;

      // Check if a background-triggered scan is pending
      final bgService = ref.read(backgroundScanProvider);
      final bgPending = await bgService.isBackgroundScanPending();
      if (!mounted) return;
      if (bgPending) {
        _autoScanTriggered = true;
        ref.read(scanStateProvider.notifier).startScan();
        return;
      }

      // Auto-scan on open if enabled
      if (autoScan) {
        _autoScanTriggered = true;
        ref.read(scanStateProvider.notifier).startScan();
      }
    });
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
              // Scan button / progress
              _ScanSection(scanState: scanState, ref: ref),
              const SizedBox(height: 16),

              // Review photos card
              _ReviewCard(ref: ref),
              const SizedBox(height: 24),

              // Storage ring
              statsAsync.when(
                data: (stats) => _StorageSection(stats: stats),
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e',
                    style: const TextStyle(
                        color: AppTheme.error)),
              ),
              const SizedBox(height: 24),

              // Quick access
              const Text('Quick Access',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.cloud_outlined,
                      label: 'Drive',
                      color: Colors.blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DriveScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAccessCard(
                      icon: Icons.lock_outline,
                      label: 'Vault',
                      color: Colors.amber,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VaultScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Important photos card
              _ImportantCard(),
              const SizedBox(height: 24),

              // Category chips
              const Text('Browse by Category',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const _CategoryGrid(),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tips',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _tipRow(Icons.search, 'Scan photos to find junk, duplicates, and blurry images'),
            _tipRow(Icons.swipe, 'Use Photo Review to quickly swipe through all photos'),
            _tipRow(Icons.auto_awesome, 'Create collages from your best photos'),
            _tipRow(Icons.lock_outline, 'Store important documents in the secure Vault'),
            _tipRow(Icons.cloud_outlined, 'Connect Google Drive to find cloud duplicates'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ScanSection extends StatelessWidget {
  final ScanState scanState;
  final WidgetRef ref;

  const _ScanSection({required this.scanState, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (scanState.isScanning) {
      final progress = scanState.progress;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  progress?.phase == 'loading'
                      ? 'Loading photo library...'
                      : progress?.phase == 'saving'
                          ? 'Saving results...'
                          : 'Scanning photos...',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (progress != null && progress.phase == 'scanning') ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.percent,
                backgroundColor: AppTheme.surface,
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.scanned} / ${progress.total} new photos — ${progress.currentFile}',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (progress.skipped > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${progress.skipped} already scanned (skipped)',
                    style: TextStyle(
                        color: AppTheme.secondary.withValues(alpha: 0.8),
                        fontSize: 11),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    final lastProgress = scanState.progress;
    final scanDone = !scanState.isScanning && lastProgress != null;
    final hasLastScan = scanState.lastScanTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Last scan info
        if (hasLastScan && !scanDone && scanState.error == null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.history,
                    color: AppTheme.textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last scan: ${_formatTimeAgo(scanState.lastScanTime!)}',
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                      ),
                      if (scanState.lastScanCount != null)
                        Text(
                          '${scanState.lastScanCount} photos'
                          '${scanState.lastScanDurationMs != null ? ' in ${_formatDuration(scanState.lastScanDurationMs!)}' : ''}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (scanState.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppTheme.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scanState.error!,
                    style: const TextStyle(
                        color: AppTheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (scanDone && scanState.error == null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.secondary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppTheme.secondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lastProgress.total > 0
                            ? 'Scanned ${lastProgress.total} new photos'
                            : lastProgress.skipped > 0
                                ? 'All ${lastProgress.skipped} photos already scanned'
                                : 'No photos found on device',
                        style: const TextStyle(
                            color: AppTheme.secondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (lastProgress.skipped > 0 && lastProgress.total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 30),
                    child: Text(
                      '${lastProgress.skipped} unchanged photos skipped',
                      style: TextStyle(
                          color: AppTheme.secondary.withValues(alpha: 0.7),
                          fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),

        // Scan buttons
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                ref.read(scanStateProvider.notifier).startScan(),
            icon: const Icon(Icons.search_rounded),
            label: Text(scanState.error != null
                ? 'Retry Scan'
                : hasLastScan || scanDone
                    ? 'Scan New Photos'
                    : 'Scan Photos'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // Full rescan option (only show if there's previous scan data)
        if (hasLastScan || scanDone) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.read(scanStateProvider.notifier).startFullRescan(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Full Re-scan'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
        // AI categorization buttons
        _buildAICategorizeSection(),
      ],
    );
  }

  Widget _buildAICategorizeSection() {
    final aiState = ref.watch(aiCategorizeStateProvider);
    final aiConfigured = ref.watch(aiServiceProvider).isConfigured;

    if (!aiConfigured && !aiState.isRunning) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(color: AppTheme.surface, height: 1),
        const SizedBox(height: 12),

        if (aiState.isRunning && aiState.progress != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.deepPurple)),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('AI Categorizing...',
                    style: TextStyle(color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 13))),
                  TextButton(
                    onPressed: () => ref.read(aiCategorizeStateProvider.notifier).cancel(),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: aiState.progress!.percent,
                  backgroundColor: AppTheme.surface,
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text(
                  '${aiState.progress!.processed}/${aiState.progress!.total} — '
                  '${aiState.progress!.succeeded} OK, ${aiState.progress!.failed} failed',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ] else if (aiState.progress?.isDone == true) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'AI categorized ${aiState.progress!.succeeded} photos',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              )),
            ]),
          ),
          const SizedBox(height: 8),
        ],

        if (!aiState.isRunning && aiConfigured) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(aiCategorizeStateProvider.notifier).start(),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Categorize with AI'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.deepPurple,
                side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.4)),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(aiCategorizeStateProvider.notifier).start(recategorize: true),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Re-categorize All'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  static String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final seconds = ms ~/ 1000;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainSec = seconds % 60;
    return '${minutes}m ${remainSec}s';
  }
}

class _ReviewCard extends ConsumerWidget {
  final WidgetRef ref;

  const _ReviewCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use count-only query — avoids loading all unreviewed PhotoAsset objects
    final countAsync = ref.watch(unreviewedCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PhotoBrowserScreen()),
            );
            ref.invalidate(unreviewedCountProvider);
            ref.invalidate(storageStatsProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.15),
                  AppTheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.swipe,
                      color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count photos to review',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Swipe to keep or delete',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary, size: 16),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StorageSection extends StatelessWidget {
  final StorageStats stats;

  const _StorageSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Storage Overview',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Center(child: StorageRing(stats: stats, size: 180)),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _LegendItem(
                color: AppTheme.primary,
                label: 'Photos',
                value:
                    '${(stats.photoBytes / (1024 * 1024)).toStringAsFixed(0)} MB'),
            _LegendItem(
                color: AppTheme.error,
                label: 'Duplicates',
                value: '${stats.duplicateCount}'),
            _LegendItem(
                color: Colors.orange,
                label: 'Junk',
                value: '${stats.junkCount}'),
            _LegendItem(
                color: AppTheme.secondary,
                label: 'Backed Up',
                value:
                    '${(stats.backedUpBytes / (1024 * 1024)).toStringAsFixed(0)} MB'),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            StatCard(
              label: 'Total Photos',
              value: '${stats.totalPhotos}',
              icon: Icons.photo_library_outlined,
              iconColor: AppTheme.primary,
            ),
            StatCard(
              label: 'Reclaimable',
              value:
                  '${stats.reclaimableMB.toStringAsFixed(0)} MB',
              icon: Icons.cleaning_services_outlined,
              iconColor: AppTheme.secondary,
              subtitle: 'Tap to clean',
            ),
            StatCard(
              label: 'Duplicates',
              value: '${stats.duplicateCount}',
              icon: Icons.copy_outlined,
              iconColor: AppTheme.error,
            ),
            StatCard(
              label: 'Junk Files',
              value: '${stats.junkCount}',
              icon: Icons.delete_outline,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem(
      {required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: $value',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      (PhotoCategory.people, Icons.people_outline, 'People', AppTheme.primary),
      (PhotoCategory.selfie, Icons.face_outlined, 'Selfie', Colors.pink),
      (PhotoCategory.food, Icons.restaurant_outlined, 'Food', Colors.orange),
      (PhotoCategory.nature, Icons.park_outlined, 'Nature', Colors.green),
      (PhotoCategory.animal, Icons.pets_outlined, 'Animal', Colors.brown),
      (PhotoCategory.travel, Icons.flight_outlined, 'Travel', Colors.teal),
      (PhotoCategory.architecture, Icons.apartment_outlined, 'Architecture', Colors.blueGrey),
      (PhotoCategory.art, Icons.palette_outlined, 'Art', Colors.deepPurple),
      (PhotoCategory.sport, Icons.sports_soccer_outlined, 'Sport', Colors.lime),
      (PhotoCategory.vehicle, Icons.directions_car_outlined, 'Vehicle', Colors.indigo),
      (PhotoCategory.night, Icons.nightlight_outlined, 'Night', Colors.deepOrange),
      (PhotoCategory.screenshots, Icons.screenshot_outlined, 'Screenshots', Colors.blue),
      (PhotoCategory.documents, Icons.description_outlined, 'Documents', Colors.purple),
      (PhotoCategory.meme, Icons.sentiment_very_satisfied_outlined, 'Meme', Colors.amber),
      (PhotoCategory.other, Icons.photo_outlined, 'Other', AppTheme.textSecondary),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: categories
          .map((c) => _CategoryTile(
                category: c.$1,
                icon: c.$2,
                label: c.$3,
                color: c.$4,
              ))
          .toList(),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final PhotoCategory category;
  final IconData icon;
  final String label;
  final Color color;

  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use count-only query — avoids loading all PhotoAsset objects per category
    final photosAsync = ref.watch(photosCountByCategoryProvider(category));

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryPhotosScreen(
              category: category,
              label: label,
              color: color,
              icon: icon,
            ),
          ),
        );
        // Refresh counts after returning (user may have deleted photos)
        ref.invalidate(photosCountByCategoryProvider(category));
        ref.invalidate(storageStatsProvider);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            photosAsync.when(
              data: (count) => Text('$count',
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11)),
              loading: () => const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportantCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(importantCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ImportantPhotosScreen()),
            );
            ref.invalidate(importantCountProvider);
            ref.invalidate(importantPhotosProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withValues(alpha: 0.15),
                  Colors.orange.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star,
                      color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count Important Photo${count > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Saved to Important folder',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: AppTheme.textSecondary, size: 14),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}


