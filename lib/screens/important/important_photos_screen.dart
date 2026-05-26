import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';
import '../../widgets/photo_preview.dart';
import '../editor/photo_editor_screen.dart';

class ImportantPhotosScreen extends ConsumerStatefulWidget {
  const ImportantPhotosScreen({super.key});

  @override
  ConsumerState<ImportantPhotosScreen> createState() =>
      _ImportantPhotosScreenState();
}

class _ImportantPhotosScreenState
    extends ConsumerState<ImportantPhotosScreen> {
  final Set<String> _selected = {};
  bool _selectMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(id);
        _selectMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
  }

  Future<void> _removeFromImportant() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Remove from Important',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Remove ${_selected.length} photo${_selected.length > 1 ? 's' : ''} from Important?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: Colors.amber))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final db = ref.read(databaseServiceProvider);
    for (final id in _selected) {
      await db.markImportant(id, important: false);
    }

    if (!mounted) return;
    final count = _selected.length;
    setState(() { _selected.clear(); _selectMode = false; });
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$count photo${count > 1 ? 's' : ''} removed from Important'),
          backgroundColor: AppTheme.secondary),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Photos',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Permanently delete ${_selected.length} photo${_selected.length > 1 ? 's' : ''}?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
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
    setState(() { _selected.clear(); _selectMode = false; });
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);
    ref.invalidate(storageStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(importantPhotosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('Important'),
          ],
        ),
        actions: [
          if (_selectMode) ...[
            IconButton(icon: const Icon(Icons.star_border, color: Colors.amber),
                tooltip: 'Remove from Important', onPressed: _removeFromImportant),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                tooltip: 'Delete', onPressed: _deleteSelected),
            IconButton(icon: const Icon(Icons.close),
                tooltip: 'Clear selection', onPressed: _clearSelection),
          ],
        ],
      ),
      body: photosAsync.when(
        data: (photos) {
          if (photos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline, color: Colors.amber, size: 64),
                  SizedBox(height: 16),
                  Text('No important photos yet',
                      style: TextStyle(color: AppTheme.textPrimary,
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text('Mark photos as important from Cleanup\nto rescue false positives',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (_, i) {
              final photo = photos[i];
              return PhotoGridTile(
                asset: photo,
                selected: _selected.contains(photo.id),
                onTap: () async {
                  if (_selectMode) {
                    _toggleSelection(photo.id);
                    return;
                  }
                  final action = await PhotoPreview.show(
                    context, asset: photo, isSelected: false,
                  );
                  if (action == null || !context.mounted) return;
                  switch (action) {
                    case 'edit':
                      await PhotoEditorScreen.open(context,
                          imagePath: photo.path, fileName: photo.name);
                    case 'unmark_important':
                      final db = ref.read(databaseServiceProvider);
                      await db.markImportant(photo.id, important: false);
                      ref.invalidate(importantPhotosProvider);
                      ref.invalidate(importantCountProvider);
                    case 'delete':
                      if (photo.path.isNotEmpty) {
                        final file = File(photo.path);
                        if (await file.exists()) await file.delete();
                        final db = ref.read(databaseServiceProvider);
                        await db.deletePhoto(photo.id);
                        ref.invalidate(importantPhotosProvider);
                        ref.invalidate(importantCountProvider);
                        ref.invalidate(storageStatsProvider);
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
          child: Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
        ),
      ),
    );
  }
}
