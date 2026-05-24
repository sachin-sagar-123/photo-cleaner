import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key});

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selected = {};
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driveSignedIn = ref.watch(driveSignedInProvider);
    final scanState = ref.watch(driveScanStateProvider);

    if (!driveSignedIn) {
      return _SignInPrompt(
        onSignIn: () => _signIn(ref),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive Analysis'),
        actions: [
          if (_selected.isNotEmpty)
            _deleting
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.error),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.error),
                    label: Text(
                      'Delete (${_selected.length})',
                      style: const TextStyle(color: AppTheme.error),
                    ),
                  ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Disconnect Drive',
            onPressed: () => _signOut(ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          onTap: (_) => setState(() => _selected.clear()),
          tabs: const [
            Tab(text: 'Duplicates'),
            Tab(text: 'Blurry'),
            Tab(text: 'Junk'),
          ],
        ),
      ),
      body: Column(
        children: [
          _ScanBanner(scanState: scanState, ref: ref),
          Expanded(
            child: scanState.isScanning
                ? _ScanningView(scanState: scanState)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _DrivePhotoList(
                        provider: driveDuplicatesProvider,
                        emptyMessage: 'No Drive duplicates found',
                        emptyIcon: Icons.check_circle_outline,
                        selected: _selected,
                        onToggle: _toggleSelection,
                        label: 'Local copy exists — safe to delete from Drive',
                        labelColor: AppTheme.error,
                      ),
                      _DrivePhotoList(
                        provider: driveBlurryProvider,
                        emptyMessage: 'No blurry photos on Drive',
                        emptyIcon: Icons.check_circle_outline,
                        selected: _selected,
                        onToggle: _toggleSelection,
                        label: 'Detected blurry via thumbnail analysis',
                        labelColor: Colors.orange,
                      ),
                      _DrivePhotoList(
                        provider: driveJunkProvider,
                        emptyMessage: 'No junk photos on Drive',
                        emptyIcon: Icons.check_circle_outline,
                        selected: _selected,
                        onToggle: _toggleSelection,
                        label: 'Detected as meme/forward/junk',
                        labelColor: Colors.orange,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _signIn(WidgetRef ref) async {
    final drive = ref.read(driveSyncServiceProvider);
    final ok = await drive.signIn();
    if (!mounted) return;
    ref.read(driveSignedInProvider.notifier).state = ok;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In failed'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _signOut(WidgetRef ref) async {
    final drive = ref.read(driveSyncServiceProvider);
    await drive.signOut();
    ref.read(driveSignedInProvider.notifier).state = false;
    setState(() => _selected.clear());
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;

    // Capture context-dependent objects before any await
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final db = ref.read(databaseServiceProvider);
    final drive = ref.read(driveSyncServiceProvider);

    final allDrive = await db.getDrivePhotos();
    final toDelete = allDrive
        .where((p) => _selected.contains(p.id) && p.driveFileId != null)
        .toList();

    if (toDelete.isEmpty || !mounted) return;

    final confirm = await showDialog<bool>(
      context: navigator.context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete from Google Drive',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permanently delete ${toDelete.length} file(s) from Google Drive?',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ This cannot be undone.',
              style: TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => navigator.pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => navigator.pop(true),
              child: const Text('Delete from Drive',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);

    final fileIds = toDelete.map((p) => p.driveFileId!).toList();

    final deleted = await drive.deleteBatchFromDrive(
      fileIds,
      onProgress: (done, total) {},
    );

    if (!mounted) return;

    setState(() {
      _deleting = false;
      _selected.clear();
    });

    ref.invalidate(drivePhotosProvider);
    ref.invalidate(driveBlurryProvider);
    ref.invalidate(driveJunkProvider);
    ref.invalidate(driveDuplicatesProvider);
    ref.invalidate(storageStatsProvider);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted $deleted file(s) from Drive'),
        backgroundColor:
            deleted > 0 ? AppTheme.secondary : AppTheme.error,
      ),
    );
  }
}

// ── Sign-in prompt ────────────────────────────────────────────────────────

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignIn;

  const _SignInPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_outlined,
                    color: Colors.blue, size: 52),
              ),
              const SizedBox(height: 24),
              const Text('Google Drive Analysis',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Connect your Google Drive to find duplicates, blurry photos, and junk — without downloading your files.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 8),
              const _FeatureRow(
                  icon: Icons.copy_outlined,
                  color: AppTheme.error,
                  text: 'Find exact duplicates via MD5 checksum'),
              const _FeatureRow(
                  icon: Icons.blur_on,
                  color: Colors.orange,
                  text: 'Detect blurry photos via thumbnail'),
              const _FeatureRow(
                  icon: Icons.delete_outline,
                  color: AppTheme.primary,
                  text: 'Delete directly from Drive'),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Connect Google Drive'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _FeatureRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
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

// ── Scan banner ───────────────────────────────────────────────────────────

class _ScanBanner extends StatelessWidget {
  final DriveScanState scanState;
  final WidgetRef ref;

  const _ScanBanner({required this.scanState, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (scanState.isScanning) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.surface,
      child: Row(
        children: [
          if (scanState.completed)
            const Icon(Icons.check_circle,
                color: AppTheme.secondary, size: 16),
          if (scanState.completed) const SizedBox(width: 8),
          Expanded(
            child: Text(
              scanState.completed
                  ? 'Drive scan complete'
                  : scanState.error != null
                      ? 'Error: ${scanState.error}'
                      : 'Scan Drive to find duplicates, blurry & junk photos',
              style: TextStyle(
                color: scanState.error != null
                    ? AppTheme.error
                    : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () =>
                ref.read(driveScanStateProvider.notifier).startScan(),
            icon: const Icon(Icons.cloud_sync_outlined, size: 16),
            label: Text(scanState.completed ? 'Re-scan' : 'Scan Drive'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scanning progress view ────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  final DriveScanState scanState;

  const _ScanningView({required this.scanState});

  @override
  Widget build(BuildContext context) {
    final progress = scanState.progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              progress?.phase == 'listing'
                  ? 'Listing Drive files...'
                  : 'Analyzing thumbnails...',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            if (progress != null && progress.total > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress.percent,
                backgroundColor: AppTheme.surface,
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Text(
                '${progress.scanned} / ${progress.total}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                progress.currentFile,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Only thumbnails are downloaded (~10 KB each).\nYour files stay on Drive.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drive photo list ──────────────────────────────────────────────────────

class _DrivePhotoList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<PhotoAsset>>> provider;
  final String emptyMessage;
  final IconData emptyIcon;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String label;
  final Color labelColor;

  const _DrivePhotoList({
    required this.provider,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.selected,
    required this.onToggle,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPhotos = ref.watch(provider);

    return asyncPhotos.when(
      data: (photos) {
        if (photos.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(emptyIcon,
                    color: AppTheme.secondary, size: 48),
                const SizedBox(height: 12),
                Text(emptyMessage,
                    style: const TextStyle(
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                const Text('Run a Drive scan first',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12)),
              ],
            ),
          );
        }

        final totalMB = photos.fold<double>(
            0, (s, p) => s + p.sizeBytes / (1024 * 1024));

        return Column(
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              color: labelColor.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: labelColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$label — ${photos.length} files, ${totalMB.toStringAsFixed(1)} MB',
                      style: TextStyle(
                          color: labelColor, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      for (final p in photos) {
                        onToggle(p.id);
                      }
                    },
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap),
                    child: Text(
                      selected.length == photos.length
                          ? 'Deselect all'
                          : 'Select all',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: photos.length,
                itemBuilder: (_, i) => _DriveFileTile(
                  asset: photos[i],
                  selected: selected.contains(photos[i].id),
                  onTap: () => onToggle(photos[i].id),
                ),
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style:
                  const TextStyle(color: AppTheme.error))),
    );
  }
}

// ── Drive file tile ───────────────────────────────────────────────────────

class _DriveFileTile extends StatelessWidget {
  final PhotoAsset asset;
  final bool selected;
  final VoidCallback onTap;

  const _DriveFileTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.error.withOpacity(0.1)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.error
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Drive icon / selection indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.error.withOpacity(0.15)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selected
                    ? Icons.check_circle
                    : Icons.cloud_outlined,
                color: selected
                    ? AppTheme.error
                    : Colors.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '${asset.sizeMB.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      if (asset.isDriveOnly)
                        _Badge(
                            label: 'Drive only',
                            color: Colors.blue),
                      if (!asset.isDriveOnly)
                        _Badge(
                            label: 'Also local',
                            color: AppTheme.secondary),
                      const SizedBox(width: 4),
                      ..._issuesBadges(asset.issues),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _formatDate(asset.createdAt),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _issuesBadges(List<QualityIssue> issues) {
    return issues.map((issue) {
      final (label, color) = switch (issue) {
        QualityIssue.blurry => ('Blurry', Colors.orange),
        QualityIssue.junk => ('Junk', Colors.deepOrange),
        QualityIssue.duplicate => ('Duplicate', AppTheme.error),
        _ => ('Issue', AppTheme.textSecondary),
      };
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: _Badge(label: label, color: color),
      );
    }).toList();
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}
