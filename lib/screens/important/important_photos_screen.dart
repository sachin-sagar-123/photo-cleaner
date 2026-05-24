import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';
import '../../widgets/photo_preview.dart';
import '../ai/ai_chat_screen.dart';
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
          'Remove ${_selected.length} photo${_selected.length > 1 ? 's' : ''} from Important? The files will remain on your device.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.amber)),
          ),
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
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$count photo${count > 1 ? 's' : ''} removed from Important'),
        backgroundColor: AppTheme.secondary,
      ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
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
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
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
            IconButton(
              icon: const Icon(Icons.star_border,
                  color: Colors.amber),
              tooltip: 'Remove from Important',
              onPressed: _removeFromImportant,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.error),
              tooltip: 'Delete',
              onPressed: _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear selection',
              onPressed: _clearSelection,
            ),
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
                  Icon(Icons.star_outline,
                      color: Colors.amber, size: 64),
                  SizedBox(height: 16),
                  Text('No important photos yet',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Text(
                      'Mark photos as important from Cleanup\nor any category view',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: AppTheme.cardColor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${photos.length} photo${photos.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_selectMode) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selected.length} selected',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Text(
                      'Saved in DCIM/PhotoCleaner Important',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
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
                          context,
                          asset: photo,
                          isSelected: false,
                        );
                        if (action == null || !context.mounted) return;
                        switch (action) {
                          case 'edit':
                            if (photo.path.isNotEmpty) {
                              await PhotoEditorScreen.open(
                                context,
                                imagePath: photo.path,
                                fileName: photo.name,
                              );
                            }
                          case 'ask_ai':
                            if (!context.mounted) return;
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => AIChatScreen(
                                initialImagePath: photo.path,
                              ),
                            ));
                          case 'unmark_important':
                            final db = ref.read(databaseServiceProvider);
                            await db.markImportant(photo.id, important: false);
                            ref.invalidate(importantPhotosProvider);
                            ref.invalidate(importantCountProvider);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Removed from important')),
                            );
                          case 'open_original':
                            if (photo.path.isNotEmpty) {
                              await OpenFilex.open(photo.path);
                            }
                        }
                      },
                      onLongPress: () => _toggleSelection(photo.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppTheme.error)),
        ),
      ),
    );
  }
}
