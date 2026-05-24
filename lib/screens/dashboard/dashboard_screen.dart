import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/storage_ring.dart';
import '../../widgets/stat_card.dart';
import '../browser/photo_browser_screen.dart';
import '../drive/drive_screen.dart';
import '../vault/vault_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(storageStatsProvider);
    final scanState = ref.watch(scanStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoCleaner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
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
              color: AppTheme.primary.withOpacity(0.3)),
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
                const Text('Scanning photos...',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.percent,
                backgroundColor:
                    AppTheme.surface,
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.scanned} / ${progress.total} — ${progress.currentFile}',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }

    final lastProgress = scanState.progress;
    final scanDone = !scanState.isScanning && lastProgress != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (scanState.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.error.withOpacity(0.3)),
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
              color: AppTheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.secondary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppTheme.secondary, size: 20),
                const SizedBox(width: 10),
                Text(
                  lastProgress.total > 0
                      ? 'Scan complete — ${lastProgress.total} photos found'
                      : 'Scan complete — no photos found on device',
                  style: const TextStyle(
                      color: AppTheme.secondary, fontSize: 13),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                ref.read(scanStateProvider.notifier).startScan(),
            icon: const Icon(Icons.search_rounded),
            label: Text(scanState.error != null
                ? 'Retry Scan'
                : scanDone
                    ? 'Re-scan Photos'
                    : 'Scan Photos'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final WidgetRef ref;

  const _ReviewCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreviewedAsync = ref.watch(unreviewedPhotosProvider);

    return unreviewedAsync.when(
      data: (photos) {
        if (photos.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PhotoBrowserScreen()),
            );
            ref.invalidate(unreviewedPhotosProvider);
            ref.invalidate(photosProvider);
            ref.invalidate(storageStatsProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withOpacity(0.15),
                  AppTheme.secondary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
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
                        '${photos.length} photos to review',
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
      (PhotoCategory.people, Icons.people_outline, 'People',
          AppTheme.primary),
      (PhotoCategory.food, Icons.restaurant_outlined, 'Food',
          Colors.orange),
      (PhotoCategory.nature, Icons.park_outlined, 'Nature',
          Colors.green),
      (PhotoCategory.screenshots, Icons.screenshot_outlined,
          'Screenshots', Colors.blue),
      (PhotoCategory.documents, Icons.description_outlined,
          'Documents', Colors.purple),
      (PhotoCategory.other, Icons.photo_outlined, 'Other',
          AppTheme.textSecondary),
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
    final photosAsync = ref.watch(photosByCategoryProvider(category));

    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: color.withOpacity(0.2), width: 1),
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
              data: (photos) => Text('${photos.length}',
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

