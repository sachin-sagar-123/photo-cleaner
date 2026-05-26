import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';
import '../../widgets/photo_preview.dart';
import '../editor/photo_editor_screen.dart';

/// Shows blurry photos detected during scan. Users can review, delete,
/// compress, or mark as important (false positive override).
class CleanupScreen extends ConsumerStatefulWidget {
  const CleanupScreen({super.key});

  @override
  ConsumerState<CleanupScreen> createState() => _CleanupScreenState();
}

class _CleanupScreenState extends ConsumerState<CleanupScreen> {
  final Set<String> _selected = {};
  CompressionMode _compressionMode = CompressionMode.smart;
  bool _compressing = false;

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
    await importantService.markMultipleAsImportant(photos);

    if (!mounted) return;
    setState(() => _selected.clear());
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(storageStatsProvider);
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count photo${count > 1 ? 's' : ''} marked as important'),
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
    final photos = await db.getPhotosByIds(_selected.toList());
    for (final photo in photos) {
      if (photo.path.isNotEmpty) {
        try {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      await db.deletePhoto(photo.id);
    }

    if (!mounted) return;
    setState(() => _selected.clear());
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(storageStatsProvider);
  }

  Future<void> _compressSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _compressing = true);

    final db = ref.read(databaseServiceProvider);
    final compression = ref.read(compressionServiceProvider);
    final toCompress = await db.getPhotosByIds(_selected.toList());

    final results = await compression.compressBatch(
      toCompress.map((p) => p.path).toList(),
      _compressionMode,
      onProgress: (done, total) {},
    );

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
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() => _compressing = false);
    ref.invalidate(blurryPhotosProvider);
    ref.invalidate(storageStatsProvider);
    if (mounted) {
      final savedMB = (totalSaved / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compressed ${results.length} photos, saved $savedMB MB'),
          backgroundColor: AppTheme.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(blurryPhotosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blurry Photos'),
        actions: [
          if (_selected.isNotEmpty) ...[
            IconButton(
              onPressed: _markImportant,
              icon: const Icon(Icons.star_outline, color: Colors.amber),
              tooltip: 'Not blurry — keep',
            ),
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              label: Text('Delete (${_selected.length})',
                  style: const TextStyle(color: AppTheme.error)),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Compression bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Row(
              children: [
                const Text('Compress:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(width: 8),
                ...CompressionMode.values.map((m) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_modeLabel(m)),
                    selected: _compressionMode == m,
                    onSelected: (_) => setState(() => _compressionMode = m),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: _compressionMode == m
                          ? AppTheme.primary : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                )),
                const Spacer(),
                if (_selected.isNotEmpty)
                  _compressing
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary))
                      : TextButton(
                          onPressed: _compressSelected,
                          child: const Text('Apply',
                              style: TextStyle(color: AppTheme.primary))),
              ],
            ),
          ),
          // Photo grid
          Expanded(
            child: photosAsync.when(
              data: (photos) {
                if (photos.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: AppTheme.secondary, size: 48),
                        SizedBox(height: 12),
                        Text('No blurry photos found',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (_, i) {
                    final photo = photos[i];
                    return PhotoGridTile(
                      asset: photo,
                      selected: _selected.contains(photo.id),
                      onTap: () async {
                        final action = await PhotoPreview.show(
                          context, asset: photo,
                          isSelected: _selected.contains(photo.id),
                        );
                        if (action == null || !context.mounted) return;
                        switch (action) {
                          case 'select' || 'deselect':
                            _toggleSelection(photo.id);
                          case 'mark_important':
                            final svc = ref.read(importantServiceProvider);
                            await svc.markAsImportant(photo);
                            ref.invalidate(blurryPhotosProvider);
                            ref.invalidate(importantPhotosProvider);
                            ref.invalidate(importantCountProvider);
                          case 'edit':
                            if (!context.mounted) return;
                            await PhotoEditorScreen.open(context,
                                imagePath: photo.path, fileName: photo.name);
                          case 'delete':
                            if (photo.path.isNotEmpty) {
                              final file = File(photo.path);
                              if (await file.exists()) await file.delete();
                              final db = ref.read(databaseServiceProvider);
                              await db.deletePhoto(photo.id);
                              ref.invalidate(blurryPhotosProvider);
                            }
                        }
                      },
                      onLongPress: () => _toggleSelection(photo.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: AppTheme.error))),
            ),
          ),
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
