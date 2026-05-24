import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_preview.dart';

class DuplicatesScreen extends ConsumerStatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  ConsumerState<DuplicatesScreen> createState() =>
      _DuplicatesScreenState();
}

class _DuplicatesScreenState
    extends ConsumerState<DuplicatesScreen> {
  final Set<String> _selectedToDelete = {};

  @override
  Widget build(BuildContext context) {
    final duplicatesAsync = ref.watch(duplicatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicates'),
        actions: [
          if (_selectedToDelete.isNotEmpty)
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.error),
              label: Text(
                'Delete (${_selectedToDelete.length})',
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
        ],
      ),
      body: duplicatesAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: AppTheme.secondary, size: 56),
                  SizedBox(height: 16),
                  Text('No duplicates found',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Run a scan to detect duplicates',
                      style: TextStyle(
                          color: AppTheme.textSecondary)),
                ],
              ),
            );
          }

          final totalWasted = groups.fold<double>(
              0, (sum, g) => sum + g.wastedMB);

          return Column(
            children: [
              _SummaryBanner(
                  groupCount: groups.length,
                  wastedMB: totalWasted),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: groups.length,
                  itemBuilder: (_, i) => _DuplicateGroupCard(
                    group: groups[i],
                    selectedIds: _selectedToDelete,
                    onToggle: (id) => setState(() {
                      if (_selectedToDelete.contains(id)) {
                        _selectedToDelete.remove(id);
                      } else {
                        _selectedToDelete.add(id);
                      }
                    }),
                    onAutoSelect: () => setState(() {
                      for (final d in groups[i].duplicates) {
                        _selectedToDelete.add(d.id);
                      }
                    }),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style:
                    const TextStyle(color: AppTheme.error))),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete Duplicates',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete ${_selectedToDelete.length} duplicate(s)?',
          style:
              const TextStyle(color: AppTheme.textSecondary),
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
    final photos = await db.getAllPhotos();

    for (final id in _selectedToDelete) {
      final photo = photos.where((p) => p.id == id).firstOrNull;
      if (photo == null) continue; // skip stale selections
      if (photo.path.isNotEmpty) {
        final file = File(photo.path);
        if (await file.exists()) await file.delete();
      }
      await db.deletePhoto(id);
    }

    setState(() => _selectedToDelete.clear());
    ref.invalidate(duplicatesProvider);
    ref.invalidate(storageStatsProvider);
  }
}

class _SummaryBanner extends StatelessWidget {
  final int groupCount;
  final double wastedMB;

  const _SummaryBanner(
      {required this.groupCount, required this.wastedMB});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_outlined,
              color: AppTheme.error, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$groupCount duplicate group${groupCount != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              Text(
                '${wastedMB.toStringAsFixed(1)} MB wasted',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateGroup group;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onAutoSelect;

  const _DuplicateGroupCard({
    required this.group,
    required this.selectedIds,
    required this.onToggle,
    required this.onAutoSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${group.assets.length} similar photos',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Text(
                      '${(group.similarity * 100).toStringAsFixed(0)}% match',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onAutoSelect,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Auto-select',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: group.assets.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final asset = group.assets[i];
                  final isBest =
                      asset.id == group.bestAsset.id;
                  final isSelected =
                      selectedIds.contains(asset.id);

                  return GestureDetector(
                    onTap: () async {
                      final action = await PhotoPreview.show(
                        context,
                        asset: asset,
                        isSelected: isSelected,
                      );
                      if (!isBest &&
                          (action == 'select' ||
                              action == 'deselect')) {
                        onToggle(asset.id);
                      }
                    },
                    onLongPress: isBest
                        ? null
                        : () => onToggle(asset.id),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(8),
                          child: Image.file(
                            File(asset.path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                              width: 100,
                              height: 100,
                              color: AppTheme.surface,
                              child: const Icon(
                                  Icons.broken_image,
                                  color:
                                      AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        if (isBest)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary
                                    .withOpacity(0.9),
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: const Text('Keep',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight:
                                          FontWeight.w700)),
                            ),
                          ),
                        if (isSelected)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.error
                                  .withOpacity(0.4),
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.error,
                                  width: 2),
                            ),
                            child: const Center(
                              child: Icon(Icons.delete,
                                  color: Colors.white,
                                  size: 24),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(asset.sizeBytes / (1024 * 1024)).toStringAsFixed(1)}M',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wasted: ${group.wastedMB.toStringAsFixed(1)} MB',
              style: const TextStyle(
                  color: AppTheme.error, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
