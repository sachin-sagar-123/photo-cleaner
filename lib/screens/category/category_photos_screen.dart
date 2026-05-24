import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';
import '../../widgets/photo_preview.dart';

class CategoryPhotosScreen extends ConsumerStatefulWidget {
  final PhotoCategory category;
  final String label;
  final Color color;
  final IconData icon;

  const CategoryPhotosScreen({
    super.key,
    required this.category,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  ConsumerState<CategoryPhotosScreen> createState() =>
      _CategoryPhotosScreenState();
}

class _CategoryPhotosScreenState
    extends ConsumerState<CategoryPhotosScreen> {
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

  void _selectAll(List<PhotoAsset> photos) {
    setState(() {
      _selected.addAll(photos.map((p) => p.id));
      _selectMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
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
          'Delete ${_selected.length} photo${_selected.length > 1 ? 's' : ''}? This cannot be undone.',
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
    ref.invalidate(photosByCategoryProvider(widget.category));
    ref.invalidate(photosCountByCategoryProvider(widget.category));
    ref.invalidate(storageStatsProvider);
    ref.invalidate(unreviewedCountProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${photos.length} photo${photos.length > 1 ? 's' : ''} deleted'),
        backgroundColor: AppTheme.secondary,
      ),
    );
  }

  Future<void> _markReviewed() async {
    if (_selected.isEmpty) return;

    final db = ref.read(databaseServiceProvider);
    await db.markAllReviewed(_selected.toList());

    if (!mounted) return;
    final count = _selected.length;
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    ref.invalidate(photosByCategoryProvider(widget.category));
    ref.invalidate(unreviewedCountProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count photo${count > 1 ? 's' : ''} marked as reviewed'),
        backgroundColor: AppTheme.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync =
        ref.watch(photosByCategoryProvider(widget.category));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.color, size: 22),
            const SizedBox(width: 8),
            Text(widget.label),
          ],
        ),
        actions: [
          if (_selectMode) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Mark reviewed',
              onPressed: _markReviewed,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.error),
              tooltip: 'Delete selected',
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon,
                      color: widget.color.withOpacity(0.3), size: 64),
                  const SizedBox(height: 16),
                  Text('No ${widget.label.toLowerCase()} photos',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15)),
                  const SizedBox(height: 8),
                  const Text('Scan your photos to categorize them',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Header bar with count and select all
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
                        color: widget.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${photos.length} photo${photos.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            color: widget.color,
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
                          color: AppTheme.primary.withOpacity(0.15),
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
                    TextButton(
                      onPressed: () {
                        if (_selected.length == photos.length) {
                          _clearSelection();
                        } else {
                          _selectAll(photos);
                        }
                      },
                      child: Text(
                        _selected.length == photos.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Photo grid
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
                          isSelected: _selected.contains(photo.id),
                        );
                        if (action == 'select' ||
                            action == 'deselect') {
                          _toggleSelection(photo.id);
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
