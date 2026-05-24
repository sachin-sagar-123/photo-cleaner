import 'package:flutter/material.dart';

import '../../../../models/models.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/stat_card.dart';
import '../../../../widgets/storage_ring.dart';

class StorageOverview extends StatelessWidget {
  final StorageStats stats;
  const StorageOverview({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Storage Overview', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Center(child: StorageRing(stats: stats, size: 180)),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _LegendItem(color: AppTheme.primary, label: 'Photos',
              value: '${(stats.photoBytes / (1024 * 1024)).toStringAsFixed(0)} MB'),
          _LegendItem(color: AppTheme.error, label: 'Duplicates',
              value: '${stats.duplicateCount}'),
          _LegendItem(color: Colors.orange, label: 'Junk',
              value: '${stats.junkCount}'),
          _LegendItem(color: AppTheme.secondary, label: 'Backed Up',
              value: '${(stats.backedUpBytes / (1024 * 1024)).toStringAsFixed(0)} MB'),
        ]),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
          children: [
            StatCard(label: 'Total Photos', value: '${stats.totalPhotos}',
                icon: Icons.photo_library_outlined, iconColor: AppTheme.primary),
            StatCard(label: 'Reclaimable',
                value: '${stats.reclaimableMB.toStringAsFixed(0)} MB',
                icon: Icons.cleaning_services_outlined, iconColor: AppTheme.secondary,
                subtitle: 'Tap to clean'),
            StatCard(label: 'Duplicates', value: '${stats.duplicateCount}',
                icon: Icons.copy_outlined, iconColor: AppTheme.error),
            StatCard(label: 'Junk Files', value: '${stats.junkCount}',
                icon: Icons.delete_outline, iconColor: Colors.orange),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendItem({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label: $value',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }
}
