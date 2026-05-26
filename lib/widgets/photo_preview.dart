import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Full-screen photo preview with pinch-zoom and action toolbar.
///
/// Returns: 'select', 'deselect', 'edit', 'mark_important',
/// 'unmark_important', 'delete', or null.
class PhotoPreview extends StatefulWidget {
  final PhotoAsset asset;
  final bool isSelected;
  final bool showDeleteAction;
  final bool showKeepAction;

  const PhotoPreview({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.showDeleteAction = true,
    this.showKeepAction = true,
  });

  static Future<String?> show(
    BuildContext context, {
    required PhotoAsset asset,
    bool isSelected = false,
    bool showDeleteAction = true,
    bool showKeepAction = true,
  }) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => PhotoPreview(
          asset: asset,
          isSelected: isSelected,
          showDeleteAction: showDeleteAction,
          showKeepAction: showKeepAction,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<PhotoPreview> {
  bool _showInfo = false;

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onDoubleTap: () => setState(() => _showInfo = !_showInfo),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo with pinch-zoom
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: asset.path.isNotEmpty
                    ? Image.file(File(asset.path), fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image, color: Colors.white54, size: 64))
                    : const Icon(Icons.image_not_supported,
                        color: Colors.white54, size: 64),
              ),
            ),

            // Issue badges
            if (asset.hasIssues)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (asset.isBlurry) _badge('Blurry', Colors.orange),
                    if (asset.isDuplicate) _badge('Duplicate', Colors.red),
                  ],
                ),
              ),

            // Important badge
            if (asset.isImportant)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Important', style: TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            // Top bar with filename + info toggle
            Positioned(
              bottom: _showInfo ? 220 : 100,
              left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${_formatDate(asset.createdAt)} · ${_formatSize(asset.sizeBytes)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Info panel
            if (_showInfo)
              Positioned(
                bottom: 100, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _infoRow(Icons.folder_outlined, 'Path',
                          asset.path.isNotEmpty ? asset.path : 'N/A'),
                      _infoRow(Icons.straighten, 'Size', _formatSize(asset.sizeBytes)),
                      _infoRow(Icons.calendar_today, 'Created', _formatDate(asset.createdAt)),
                      if (asset.hasIssues)
                        _infoRow(Icons.warning_outlined, 'Issues',
                            asset.issues.map((i) => i.name).join(', ')),
                    ],
                  ),
                ),
              ),

            // Action toolbar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 8, right: 8, top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                color: Colors.black.withValues(alpha: 0.9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionBtn(Icons.info_outline, 'Info', () {
                      setState(() => _showInfo = !_showInfo);
                    }),
                    _actionBtn(Icons.edit_outlined, 'Edit', () {
                      Navigator.pop(context, 'edit');
                    }),
                    if (asset.isImportant)
                      _actionBtn(Icons.star, 'Unmark', () {
                        Navigator.pop(context, 'unmark_important');
                      }, color: Colors.amber)
                    else
                      _actionBtn(Icons.star_outline, 'Keep', () {
                        Navigator.pop(context, 'mark_important');
                      }),
                    _actionBtn(
                      widget.isSelected ? Icons.check_circle : Icons.circle_outlined,
                      widget.isSelected ? 'Selected' : 'Select',
                      () => Navigator.pop(context, widget.isSelected ? 'deselect' : 'select'),
                      color: widget.isSelected ? AppTheme.primary : null,
                    ),
                    if (widget.showDeleteAction)
                      _actionBtn(Icons.delete_outline, 'Delete', () {
                        Navigator.pop(context, 'delete');
                      }, color: AppTheme.error),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
                color: color ?? Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(
              color: Colors.white54, fontSize: 12)),
          Expanded(child: Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
