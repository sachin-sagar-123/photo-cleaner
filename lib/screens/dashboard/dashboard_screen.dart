import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/scanner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/storage_ring.dart';
import '../important/important_photos_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanStateProvider);
    final statsAsync = ref.watch(storageStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoCleaner'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scan section
          _ScanSection(scanState: scanState, ref: ref),
          const SizedBox(height: 20),

          // Storage overview
          statsAsync.when(
            data: (stats) => _StorageCard(stats: stats),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Quick access cards
          _QuickAccessGrid(ref: ref),
        ],
      ),
    );
  }
}

// ── Scan Section ──────────────────────────────────────────────────────────

class _ScanSection extends StatelessWidget {
  final ScanState scanState;
  final WidgetRef ref;

  const _ScanSection({required this.scanState, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (scanState.isScanning) return _buildProgress();
    return _buildIdle();
  }

  Widget _buildProgress() {
    final progress = scanState.progress;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
            const SizedBox(width: 12),
            Text(
              progress?.phase == 'loading' ? 'Loading photo library...'
                  : progress?.phase == 'saving' ? 'Saving results...'
                  : 'Scanning photos...',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
          ]),
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
              '${progress.scanned} / ${progress.total} new photos',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            if (progress.skipped > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${progress.skipped} already scanned (skipped)',
                  style: TextStyle(color: AppTheme.secondary.withValues(alpha: 0.8), fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdle() {
    final lastProgress = scanState.progress;
    final scanDone = !scanState.isScanning && lastProgress != null;
    final hasLastScan = scanState.lastScanTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLastScan && !scanDone && scanState.error == null)
          _lastScanInfo(),
        if (scanState.error != null) _errorInfo(),
        if (scanDone && scanState.error == null) _completedInfo(lastProgress),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => ref.read(scanStateProvider.notifier).startScan(),
            icon: const Icon(Icons.search_rounded),
            label: Text(scanState.error != null ? 'Retry Scan'
                : hasLastScan || scanDone ? 'Scan New Photos' : 'Scan Photos'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (hasLastScan || scanDone) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(scanStateProvider.notifier).startFullRescan(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Full Re-scan'),
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

  Widget _lastScanInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.history, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last scan: ${_formatTimeAgo(scanState.lastScanTime!)}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            if (scanState.lastScanCount != null)
              Text(
                '${scanState.lastScanCount} photos'
                '${scanState.lastScanDurationMs != null ? ' in ${_formatDuration(scanState.lastScanDurationMs!)}' : ''}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        )),
      ]),
    );
  }

  Widget _errorInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(scanState.error!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13))),
      ]),
    );
  }

  Widget _completedInfo(ScanProgress progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline, color: AppTheme.secondary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          progress.total > 0 ? 'Scanned ${progress.total} new photos'
              : progress.skipped > 0 ? 'All ${progress.skipped} photos already scanned'
              : 'No photos found on device',
          style: const TextStyle(color: AppTheme.secondary, fontSize: 13),
        )),
      ]),
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
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }
}

// ── Storage Card ──────────────────────────────────────────────────────────

class _StorageCard extends StatelessWidget {
  final StorageStats stats;

  const _StorageCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100, height: 100,
            child: StorageRing(stats: stats),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${stats.totalPhotos} photos',
                    style: const TextStyle(color: AppTheme.textPrimary,
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${_formatBytes(stats.photoBytes)} total',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                if (stats.duplicateCount > 0) ...[
                  const SizedBox(height: 4),
                  Text('${stats.duplicateCount} duplicates (${_formatBytes(stats.duplicateBytes)})',
                      style: TextStyle(color: Colors.orange.shade300, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ── Quick Access Grid ─────────────────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  final WidgetRef ref;

  const _QuickAccessGrid({required this.ref});

  @override
  Widget build(BuildContext context) {
    final blurryAsync = ref.watch(blurryPhotosProvider);
    final dupsAsync = ref.watch(duplicatesProvider);
    final importantAsync = ref.watch(importantCountProvider);

    final blurryCount = blurryAsync.valueOrNull?.length ?? 0;
    final dupCount = dupsAsync.valueOrNull?.length ?? 0;
    final importantCount = importantAsync.valueOrNull ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionCard(
              icon: Icons.blur_on, label: 'Blurry',
              count: blurryCount, color: Colors.orange,
              onTap: () => _switchTab(context, 1),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionCard(
              icon: Icons.copy, label: 'Duplicates',
              count: dupCount, color: Colors.red,
              onTap: () => _switchTab(context, 2),
            )),
          ],
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.star, label: 'Important Photos',
          count: importantCount, color: Colors.amber,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ImportantPhotosScreen(),
          )),
          wide: true,
        ),
      ],
    );
  }

  void _switchTab(BuildContext context, int index) {
    // Find the MainShell ancestor and switch tab
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    // Use a callback to switch the tab in MainShell
    // For now, navigate by pushing the screen directly
    if (index == 1) {
      // Already on cleanup tab — just switch
    } else if (index == 2) {
      // Already on duplicates tab — just switch
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final bool wide;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w500)),
                  Text('$count found', style: TextStyle(
                      color: color.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
