import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';

class CleanupScreen extends ConsumerStatefulWidget {
  const CleanupScreen({super.key});

  @override
  ConsumerState<CleanupScreen> createState() => _CleanupScreenState();
}

class _CleanupScreenState extends ConsumerState<CleanupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selected = {};
  CompressionMode _compressionMode = CompressionMode.smart;
  bool _compressing = false;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleanup'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.error),
              label: Text(
                'Delete (${_selected.length})',
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Junk'),
            Tab(text: 'Blurry'),
            Tab(text: 'Backed Up'),
          ],
        ),
      ),
      body: Column(
        children: [
          _CompressionBar(
            mode: _compressionMode,
            compressing: _compressing,
            selectedCount: _selected.length,
            onModeChanged: (m) =>
                setState(() => _compressionMode = m),
            onCompress: _compressSelected,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PhotoList(
                  filter: (p) =>
                      p.issues.contains(QualityIssue.junk),
                  selected: _selected,
                  onToggle: _toggleSelection,
                ),
                _PhotoList(
                  filter: (p) =>
                      p.issues.contains(QualityIssue.blurry),
                  selected: _selected,
                  onToggle: _toggleSelection,
                ),
                _PhotoList(
                  filter: (p) => p.isBackedUp,
                  selected: _selected,
                  onToggle: _toggleSelection,
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

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Photos',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete ${_selected.length} photo(s)? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm != true) return;

    final db = ref.read(databaseServiceProvider);
    for (final id in _selected) {
      final photos = await db.getAllPhotos();
      final photo =
          photos.firstWhere((p) => p.id == id, orElse: () => photos.first);
      final file = File(photo.path);
      if (await file.exists()) await file.delete();
      await db.deletePhoto(id);
    }

    setState(() => _selected.clear());
    ref.invalidate(photosProvider);
    ref.invalidate(storageStatsProvider);
  }

  Future<void> _compressSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _compressing = true);

    final db = ref.read(databaseServiceProvider);
    final compression = ref.read(compressionServiceProvider);
    final photos = await db.getAllPhotos();
    final toCompress =
        photos.where((p) => _selected.contains(p.id)).toList();

    await compression.compressBatch(
      toCompress.map((p) => p.path).toList(),
      _compressionMode,
      onProgress: (done, total) {},
    );

    setState(() => _compressing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compressed ${toCompress.length} photos'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    }
  }
}

class _CompressionBar extends StatelessWidget {
  final CompressionMode mode;
  final bool compressing;
  final int selectedCount;
  final ValueChanged<CompressionMode> onModeChanged;
  final VoidCallback onCompress;

  const _CompressionBar({
    required this.mode,
    required this.compressing,
    required this.selectedCount,
    required this.onModeChanged,
    required this.onCompress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.surface,
      child: Row(
        children: [
          const Text('Compress:',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          ...CompressionMode.values.map((m) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(_modeLabel(m)),
                  selected: mode == m,
                  onSelected: (_) => onModeChanged(m),
                  selectedColor: AppTheme.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: mode == m
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              )),
          const Spacer(),
          if (selectedCount > 0)
            compressing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary))
                : TextButton(
                    onPressed: onCompress,
                    child: const Text('Apply',
                        style: TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
  }

  String _modeLabel(CompressionMode m) => switch (m) {
        CompressionMode.lossless => 'Lossless',
        CompressionMode.smart => 'Smart',
        CompressionMode.aggressive => 'Max',
      };
}

class _PhotoList extends ConsumerWidget {
  final bool Function(PhotoAsset) filter;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _PhotoList({
    required this.filter,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(photosProvider);

    return photosAsync.when(
      data: (all) {
        final photos = all.where(filter).toList();
        if (photos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppTheme.secondary, size: 48),
                SizedBox(height: 12),
                Text('Nothing to clean here',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: photos.length,
          itemBuilder: (_, i) => PhotoGridTile(
            asset: photos[i],
            selected: selected.contains(photos[i].id),
            onTap: () => onToggle(photos[i].id),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.error))),
    );
  }
}
