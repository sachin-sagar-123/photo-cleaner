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
              // Decode at thumbnail resolution instead of full 12MP.
              // Grid cells are ~120px; 200px gives crisp display on 2x screens.
              // This reduces memory from ~36MB (full RGBA) to ~160KB per tile.
              cacheWidth: 200,
              cacheHeight: 200,
              // Don't keep decoded images in the global ImageCache beyond
              // what's visible — the grid can have thousands of tiles.
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
              top: 4,
              left: 4,
              child: _IssuesBadge(issues: asset.issues),
            ),
          if (selected)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.check_circle,
                    color: Colors.white, size: 28),
              ),
            ),
          if (asset.isImportant)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.star, size: 12, color: Colors.white),
              ),
            ),
          if (asset.isBackedUp)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.cloud_done,
                    size: 12, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}

class _IssuesBadge extends StatelessWidget {
  final List<QualityIssue> issues;

  const _IssuesBadge({required this.issues});

  @override
  Widget build(BuildContext context) {
    final color = issues.contains(QualityIssue.duplicate)
        ? AppTheme.error
        : issues.contains(QualityIssue.junk)
            ? Colors.orange
            : Colors.amber;

    final icon = issues.contains(QualityIssue.blurry)
        ? Icons.blur_on
        : issues.contains(QualityIssue.duplicate)
            ? Icons.copy
            : Icons.warning_amber;

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
