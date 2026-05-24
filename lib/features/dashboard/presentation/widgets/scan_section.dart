import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart'
    show aiCategorizeStateProvider, aiServiceProvider;
import '../../../../services/scanner_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../scan/presentation/providers/scan_providers.dart';

class ScanSection extends StatelessWidget {
  final ScanState scanState;
  final WidgetRef ref;

  const ScanSection({super.key, required this.scanState, required this.ref});

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
              '${progress.scanned} / ${progress.total} new photos — ${progress.currentFile}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
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
        // AI categorization section
        _AICategorizeSection(ref: ref),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.secondary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              progress.total > 0 ? 'Scanned ${progress.total} new photos'
                  : progress.skipped > 0 ? 'All ${progress.skipped} photos already scanned'
                  : 'No photos found on device',
              style: const TextStyle(color: AppTheme.secondary, fontSize: 13),
            )),
          ]),
          if (progress.skipped > 0 && progress.total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 30),
              child: Text('${progress.skipped} unchanged photos skipped',
                  style: TextStyle(color: AppTheme.secondary.withValues(alpha: 0.7), fontSize: 11)),
            ),
        ],
      ),
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

/// AI categorization progress + re-categorize button.
class _AICategorizeSection extends StatelessWidget {
  final WidgetRef ref;

  const _AICategorizeSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiCategorizeStateProvider);
    final aiConfigured = ref.watch(aiServiceProvider).isConfigured;

    // Show nothing if AI is not configured and not running
    if (!aiConfigured && !aiState.isRunning) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(color: AppTheme.surface, height: 1),
        const SizedBox(height: 12),

        if (aiState.isRunning && aiState.progress != null) ...[
          // Progress indicator
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
                  '${aiState.progress!.succeeded} OK, ${aiState.progress!.failed} failed'
                  '${aiState.progress!.currentFile.isNotEmpty ? ' — ${aiState.progress!.currentFile}' : ''}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ] else if (aiState.progress?.isDone == true) ...[
          // Completed summary
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

        // Re-categorize button (only when not running)
        if (!aiState.isRunning && aiConfigured)
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

        if (!aiState.isRunning && aiConfigured) ...[
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
}
