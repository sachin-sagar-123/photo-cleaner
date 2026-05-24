import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_grid_tile.dart';
import '../../widgets/photo_preview.dart';
import '../ai/ai_chat_screen.dart';
import '../editor/photo_editor_screen.dart';

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

enum _SortMode { dateDesc, dateAsc, sizeDesc, sizeAsc, name }

class _CategoryPhotosScreenState
    extends ConsumerState<CategoryPhotosScreen> {
  final Set<String> _selected = {};
  bool _selectMode = false;
  _SortMode _sortMode = _SortMode.dateDesc;
  bool _showImportantOnly = false;
  bool _showIssuesOnly = false;

  List<PhotoAsset> _applySortAndFilter(List<PhotoAsset> photos) {
    var result = photos.toList();

    // Filters
    if (_showImportantOnly) {
      result = result.where((p) => p.isImportant).toList();
    }
    if (_showIssuesOnly) {
      result = result.where((p) => p.hasIssues).toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.dateDesc:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortMode.dateAsc:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortMode.sizeDesc:
        result.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case _SortMode.sizeAsc:
        result.sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
      case _SortMode.name:
        result.sort((a, b) => a.name.compareTo(b.name));
    }
    return result;
  }

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

  Future<void> _markImportant() async {
    if (_selected.isEmpty) return;

    final db = ref.read(databaseServiceProvider);
    final importantService = ref.read(importantServiceProvider);
    final photos = await db.getPhotosByIds(_selected.toList());

    if (!mounted) return;
    final count = photos.length;
    await importantService.markMultipleAsImportant(photos);

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    ref.invalidate(photosByCategoryProvider(widget.category));
    ref.invalidate(photosCountByCategoryProvider(widget.category));
    ref.invalidate(importantPhotosProvider);
    ref.invalidate(importantCountProvider);
    ref.invalidate(storageStatsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$count photo${count > 1 ? 's' : ''} marked as important'),
        backgroundColor: Colors.amber.shade700,
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
              icon: const Icon(Icons.star_outline,
                  color: Colors.amber),
              tooltip: 'Mark as important',
              onPressed: _markImportant,
            ),
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
                      color: widget.color.withValues(alpha: 0.3), size: 64),
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

          final filtered = _applySortAndFilter(photos);

          return Column(
            children: [
              // Header bar with count, sort, filter
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                color: AppTheme.cardColor,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${filtered.length}${filtered.length != photos.length ? '/${photos.length}' : ''} photo${filtered.length != 1 ? 's' : ''}',
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
                        TextButton(
                          onPressed: () {
                            if (_selected.length == filtered.length) {
                              _clearSelection();
                            } else {
                              _selectAll(filtered);
                            }
                          },
                          child: Text(
                            _selected.length == filtered.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Sort + filter chips
                    SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _sortChip('Newest', _SortMode.dateDesc),
                          _sortChip('Oldest', _SortMode.dateAsc),
                          _sortChip('Largest', _SortMode.sizeDesc),
                          _sortChip('Smallest', _SortMode.sizeAsc),
                          _sortChip('Name', _SortMode.name),
                          const SizedBox(width: 8),
                          _filterChip('⭐ Important', _showImportantOnly,
                              (v) => setState(() => _showImportantOnly = v)),
                          _filterChip('⚠ Issues', _showIssuesOnly,
                              (v) => setState(() => _showIssuesOnly = v)),
                        ],
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
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final photo = filtered[i];
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
                        if (action == null) return;
                        if (!context.mounted) return;
                        await _handlePreviewAction(
                            context, ref, action, photo);
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

  Widget _sortChip(String label, _SortMode mode) {
    final active = _sortMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: active,
        onSelected: (_) => setState(() => _sortMode = mode),
        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: active ? AppTheme.primary : AppTheme.textSecondary,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }

  Widget _filterChip(String label, bool active, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: active,
        onSelected: onChanged,
        selectedColor: Colors.amber.withValues(alpha: 0.2),
        checkmarkColor: Colors.amber,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Future<void> _handlePreviewAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    PhotoAsset photo,
  ) async {
    switch (action) {
      case 'select' || 'deselect':
        _toggleSelection(photo.id);
      case 'mark_important':
        final svc = ref.read(importantServiceProvider);
        await svc.markAsImportant(photo);
        ref.invalidate(photosByCategoryProvider(widget.category));
        ref.invalidate(importantPhotosProvider);
        ref.invalidate(importantCountProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${photo.name} marked as important'),
            backgroundColor: Colors.amber.shade700,
          ),
        );
      case 'unmark_important':
        final db = ref.read(databaseServiceProvider);
        await db.markImportant(photo.id, important: false);
        ref.invalidate(photosByCategoryProvider(widget.category));
        ref.invalidate(importantPhotosProvider);
        ref.invalidate(importantCountProvider);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from important')),
        );
      case 'edit':
        await PhotoEditorScreen.open(
          context,
          imagePath: photo.path,
          fileName: photo.name,
        );
      case 'ask_ai':
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AIChatScreen(initialImagePath: photo.path),
          ),
        );
      case 'open_original':
        if (photo.path.isNotEmpty) {
          await OpenFilex.open(photo.path);
        }
      case 'delete':
        if (photo.path.isNotEmpty) {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
          final db = ref.read(databaseServiceProvider);
          await db.deletePhoto(photo.id);
          ref.invalidate(photosByCategoryProvider(widget.category));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${photo.name} deleted')),
          );
        }
    }
  }
}
