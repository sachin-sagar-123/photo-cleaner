import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_theme.dart';
import '../../../../screens/important/important_photos_screen.dart';
import '../../../important/presentation/providers/important_providers.dart';

class ImportantCard extends ConsumerWidget {
  const ImportantCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(importantCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ImportantPhotosScreen()));
            ref.invalidate(importantCountProvider);
            ref.invalidate(importantPhotosProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.amber.withOpacity(0.15),
                Colors.orange.withOpacity(0.1),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count Important Photo${count > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const Text('Saved to Important folder',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              )),
              const Icon(Icons.arrow_forward_ios,
                  color: AppTheme.textSecondary, size: 14),
            ]),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
