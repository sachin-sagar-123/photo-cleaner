import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class PhotoGridTile extends StatelessWidget {
  final PhotoAsset asset;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PhotoGridTile({
    super.key,
    required this.asset,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(asset.path),
              fit: BoxFit.cover,
              cacheWidth: 200,
              cacheHeight: 200,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.surface,
                child: const Icon(Icons.broken_image,
                    color: AppTheme.textSecondary),
              ),
            ),
          ),
          if (asset.hasIssues)
            Positioned(
              top: 4, left: 4,
              child: _IssueBadge(issues: asset.issues),
            ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.check_circle, color: Colors.white, size: 28),
              ),
            ),
          if (asset.isImportant)
            Positioned(
              top: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.star, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _IssueBadge extends StatelessWidget {
  final List<QualityIssue> issues;

  const _IssueBadge({required this.issues});

  @override
  Widget build(BuildContext context) {
    final isBlurry = issues.contains(QualityIssue.blurry);
    final isDup = issues.contains(QualityIssue.duplicate);

    final color = isDup ? AppTheme.error : Colors.orange;
    final icon = isBlurry ? Icons.blur_on : Icons.copy;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}
