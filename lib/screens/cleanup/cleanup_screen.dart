import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';
import '../../widgets/photo_preview.dart';
import '../ai/ai_chat_screen.dart';
import '../editor/photo_editor_screen.dart';

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
          if (_selected.isNotEmpty) ...[
            // "Mark Important" — removes the issue flag and marks reviewed
            if (_tabController.index < 2) // Junk or Blurry tab
              IconButton(
                onPressed: _markImportant,
                icon: const Icon(Icons.star_outline,
                    color: Colors.amber),
                tooltip: 'Mark as important',
              ),
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
                _FilteredPhotoList(
                  provider: junkPhotosProvider,
                  selected: _selected,
                  onToggle: _toggleSelection,
                ),
                _FilteredPhotoList(
                  provider: blurryPhotosProvider,
                  selected: _selected,
                  onToggle: _toggleSelection,
                ),
                _FilteredPhotoList(
                  provider: backedUpCleanupProvider,
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

  Future<void> _markImportant() async {
    if (_selected.isEmpty) return;

    final db = ref.read(databaseServiceProvider);
    final importantService = ref.read(importantServiceProvider);
    final photos = await db.getPhotosByIds(_selected.toList());

    if (!mounted) return;
    final count = photos.length;
    final moved = await importantService.markMultipleAsImportant(photos);

    if (!mounted) return;
    setState(() => _selected.clear());
    ref.invalidate(junkPhotosProvider);
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(storageStatsProvider);
    ref.invalidate(unreviewedCountProvider);
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$count photo${count > 1 ? 's' : ''} marked as important'
            '${moved > 0 ? ' — moved to Important folder' : ''}'),
        backgroundColor: Colors.amber.shade700,
      ),
    );
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

    if (confirm != true || !mounted) return;

    final db = ref.read(databaseServiceProvider);
    // Fetch only the selected photos instead of all 16K
    final photos = await db.getPhotosByIds(_selected.toList());
    for (final photo in photos) {
      if (photo.path.isNotEmpty) {
        try {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // File already deleted or inaccessible
        }
      }
      await db.deletePhoto(photo.id);
    }

    if (!mounted) return;
    setState(() => _selected.clear());
    ref.invalidate(junkPhotosProvider);
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(backedUpCleanupProvider);
    ref.invalidate(storageStatsProvider);
    ref.invalidate(unreviewedCountProvider);
  }

  Future<void> _compressSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _compressing = true);

    final db = ref.read(databaseServiceProvider);
    final compression = ref.read(compressionServiceProvider);
    // Fetch only the selected photos instead of all 16K
    final toCompress = await db.getPhotosByIds(_selected.toList());

    final results = await compression.compressBatch(
      toCompress.map((p) => p.path).toList(),
      _compressionMode,
      onProgress: (done, total) {},
    );

    // Replace originals with compressed versions
    int totalSaved = 0;
    for (final result in results) {
      if (result.compressedBytes < result.originalBytes) {
        try {
          final compressedFile = File(result.compressedPath);
          final originalFile = File(result.originalPath);
          if (await compressedFile.exists() && await originalFile.exists()) {
            await compressedFile.copy(result.originalPath);
            await compressedFile.delete();
            totalSaved += result.originalBytes - result.compressedBytes;
          }
        } catch (_) {
          // Skip files that fail to replace
        }
      }
    }

    if (!mounted) return;
    setState(() => _compressing = false);
    ref.invalidate(junkPhotosProvider);
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(backedUpCleanupProvider);
    ref.invalidate(storageStatsProvider);
    if (mounted) {
      final savedMB = (totalSaved / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Compressed ${results.length} photos, saved $savedMB MB'),
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

/// Uses a pre-filtered provider instead of loading all photos and filtering
/// client-side. For 16K photos this avoids ~50MB of unnecessary allocations.
class _FilteredPhotoList extends ConsumerWidget {
  final FutureProvider<List<PhotoAsset>> provider;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _FilteredPhotoList({
    required this.provider,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(provider);

    return photosAsync.when(
      data: (photos) {
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
          itemBuilder: (_, i) {
            final photo = photos[i];
            return PhotoGridTile(
              asset: photo,
              selected: selected.contains(photo.id),
              onTap: () async {
                final action = await PhotoPreview.show(
                  context,
                  asset: photo,
                  isSelected: selected.contains(photo.id),
                );
                if (action == 'select' || action == 'deselect') {
                  onToggle(photo.id);
                } else if (action == 'mark_important') {
                  await _handleMarkImportant(context, ref, photo);
                } else if (action == 'edit') {
                  await PhotoEditorScreen.open(
                    context,
                    imagePath: photo.path,
                    fileName: photo.name,
                  );
                } else if (action == 'ask_ai') {
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AIChatScreen(
                        initialImagePath: photo.path,
                      ),
                    ));
                  }
                }
              },
              onLongPress: () => onToggle(photo.id),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.error))),
    );
  }

  Future<void> _handleMarkImportant(
      BuildContext context, WidgetRef ref, PhotoAsset photo) async {
    final importantService = ref.read(importantServiceProvider);
    final result = await importantService.markAsImportant(photo);

    ref.invalidate(junkPhotosProvider);
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(storageStatsProvider);
    ref.invalidate(unreviewedCountProvider);
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${photo.name} marked as important'
            '${result != null ? ' — moved to Important folder' : ''}'),
        backgroundColor: Colors.amber.shade700,
      ),
    );
  }
}
