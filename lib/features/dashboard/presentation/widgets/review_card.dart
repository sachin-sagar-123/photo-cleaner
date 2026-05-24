import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../../../screens/browser/photo_browser_screen.dart';
import '../providers/dashboard_providers.dart';

class ReviewCard extends ConsumerWidget {
  const ReviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreviewedCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PhotoBrowserScreen()));
            ref.invalidate(unreviewedCountProvider);
            ref.invalidate(storageStatsProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primary.withOpacity(0.15),
                AppTheme.secondary.withOpacity(0.1),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swipe, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count photos to review', style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Text('Swipe to keep or delete', style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
                ],
              )),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
            ]),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
