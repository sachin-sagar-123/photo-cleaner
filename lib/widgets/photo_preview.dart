import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Full-screen photo preview with metadata and actions.
/// Returns the action taken: 'select', 'deselect', or null (dismissed).
class PhotoPreview extends StatelessWidget {
  final PhotoAsset asset;
  final bool isSelected;

  const PhotoPreview({
    super.key,
    required this.asset,
    this.isSelected = false,
  });

  /// Shows the preview and returns the action: 'select', 'deselect', or null.
  static Future<String?> show(
    BuildContext context, {
    required PhotoAsset asset,
    bool isSelected = false,
  }) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => PhotoPreview(
          asset: asset,
          isSelected: isSelected,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // File info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        asset.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${asset.sizeMB.toStringAsFixed(1)} MB · ${_formatDate(asset.createdAt)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Issue badges
            if (asset.hasIssues)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: asset.issues.map((issue) {
                    final (label, color, icon) = _issueInfo(issue);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 14),
                          const SizedBox(width: 4),
                          Text(label,
                              style: TextStyle(
                                  color: color, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Photo
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: asset.path.isNotEmpty
                      ? Image.file(
                          File(asset.path),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image,
                                  color: Colors.white54, size: 64),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_outlined,
                                color: Colors.white54, size: 64),
                            SizedBox(height: 12),
                            Text('Drive-only photo',
                                style: TextStyle(
                                    color: Colors.white54)),
                            Text('No local preview available',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12)),
                          ],
                        ),
                ),
              ),
            ),

            // Bottom actions
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              color: AppTheme.surface,
              child: Row(
                children: [
                  // Category & suggested name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.category.name.toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1),
                        ),
                        if (asset.suggestedName != null)
                          Text(
                            asset.suggestedName!,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (asset.isBackedUp)
                          const Row(
                            children: [
                              Icon(Icons.cloud_done,
                                  color: AppTheme.secondary,
                                  size: 12),
                              SizedBox(width: 4),
                              Text('Backed up',
                                  style: TextStyle(
                                      color: AppTheme.secondary,
                                      fontSize: 11)),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Select / Deselect for deletion
                  if (isSelected)
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, 'deselect'),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Keep'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, 'select'),
                      icon: const Icon(Icons.delete_outline,
                          size: 18),
                      label: const Text('Select to Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, IconData) _issueInfo(QualityIssue issue) =>
      switch (issue) {
        QualityIssue.blurry => ('Blurry', Colors.orange, Icons.blur_on),
        QualityIssue.closedEyes =>
          ('Closed Eyes', Colors.amber, Icons.visibility_off),
        QualityIssue.lowLight =>
          ('Low Light', Colors.amber, Icons.dark_mode),
        QualityIssue.duplicate =>
          ('Duplicate', AppTheme.error, Icons.copy),
        QualityIssue.junk =>
          ('Junk', Colors.deepOrange, Icons.delete_outline),
      };

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}
