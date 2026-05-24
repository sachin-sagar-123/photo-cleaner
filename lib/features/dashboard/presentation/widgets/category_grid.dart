import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/models.dart';
import '../../../../theme/app_theme.dart';
import '../../../../screens/category/category_photos_screen.dart';
import '../providers/dashboard_providers.dart';

class CategoryGrid extends ConsumerWidget {
  const CategoryGrid({super.key});

  static const _categories = [
    (PhotoCategory.people, Icons.people_outline, 'People', AppTheme.primary),
    (PhotoCategory.food, Icons.restaurant_outlined, 'Food', Colors.orange),
    (PhotoCategory.nature, Icons.park_outlined, 'Nature', Colors.green),
    (PhotoCategory.screenshots, Icons.screenshot_outlined, 'Screenshots', Colors.blue),
    (PhotoCategory.documents, Icons.description_outlined, 'Documents', Colors.purple),
    (PhotoCategory.other, Icons.photo_outlined, 'Other', AppTheme.textSecondary),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.1,
      children: _categories.map((c) => _CategoryTile(
        category: c.$1, icon: c.$2, label: c.$3, color: c.$4,
      )).toList(),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final PhotoCategory category;
  final IconData icon;
  final String label;
  final Color color;

  const _CategoryTile({
    required this.category, required this.icon,
    required this.label, required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(photosCountByCategoryProvider(category));

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => CategoryPhotosScreen(
            category: category, label: label, color: color, icon: icon),
        ));
        ref.invalidate(photosCountByCategoryProvider(category));
        ref.invalidate(storageStatsProvider);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
            countAsync.when(
              data: (count) => Text('$count', style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11)),
              loading: () => const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
