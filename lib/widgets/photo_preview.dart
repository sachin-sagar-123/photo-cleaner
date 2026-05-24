import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Full-screen photo preview with pinch-zoom, metadata, EXIF info,
/// and a complete action toolbar.
///
/// Returns the action taken: 'select', 'deselect', 'edit', 'mark_important',
/// 'unmark_important', 'ask_ai', 'delete', 'share', 'open_original', or null.
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
    final hasFile = asset.path.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            _TopBar(
              asset: asset,
              onClose: () => Navigator.pop(context),
              onInfo: () => setState(() => _showInfo = !_showInfo),
              showingInfo: _showInfo,
            ),

            // ── Photo with pinch-zoom ─────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onDoubleTap: () => setState(() => _showInfo = !_showInfo),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: hasFile
                          ? Image.file(
                              File(asset.path),
                              fit: BoxFit.contain,
                              cacheWidth: (MediaQuery.of(context).size.width * 2).toInt(),
                              errorBuilder: (_, __, ___) => _brokenImage(),
                            )
                          : _brokenImage(),
                    ),
                  ),

                  // Info overlay
                  if (_showInfo)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _InfoPanel(asset: asset),
                    ),

                  // Issue badges
                  if (asset.issues.isNotEmpty && !_showInfo)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Wrap(
                        spacing: 6,
                        children: asset.issues.map((i) {
                          final info = _issueInfo(i);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: info.$2.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(info.$3, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(info.$1,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Important badge
                  if (asset.isImportant)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.star, color: Colors.amber, size: 28),
                    ),
                ],
              ),
            ),

            // ── Action toolbar ────────────────────────────────────────────
            _ActionToolbar(
              asset: asset,
              isSelected: widget.isSelected,
              showDeleteAction: widget.showDeleteAction,
              showKeepAction: widget.showKeepAction,
              onAction: (action) => Navigator.pop(context, action),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brokenImage() => Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.white38, size: 48),
        ),
      );

  (String, Color, IconData) _issueInfo(QualityIssue issue) => switch (issue) {
        QualityIssue.blurry => ('Blurry', Colors.orange, Icons.blur_on),
        QualityIssue.closedEyes =>
          ('Closed Eyes', Colors.amber, Icons.visibility_off),
        QualityIssue.lowLight => ('Low Light', Colors.amber, Icons.dark_mode),
        QualityIssue.duplicate => ('Duplicate', AppTheme.error, Icons.copy),
        QualityIssue.junk =>
          ('Junk', Colors.deepOrange, Icons.delete_outline),
      };
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final PhotoAsset asset;
  final VoidCallback onClose;
  final VoidCallback onInfo;
  final bool showingInfo;

  const _TopBar({
    required this.asset,
    required this.onClose,
    required this.onInfo,
    required this.showingInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: Colors.black54,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  '${_formatDate(asset.createdAt)} · ${_formatSize(asset.sizeBytes)} · ${asset.effectiveCategory.displayName}${asset.hasAICategory ? ' (AI)' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              showingInfo ? Icons.info : Icons.info_outline,
              color: showingInfo ? AppTheme.primary : Colors.white70,
            ),
            tooltip: 'Photo details',
            onPressed: onInfo,
          ),
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

// ── Info panel (EXIF, path, location) ───────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final PhotoAsset asset;

  const _InfoPanel({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.95),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40), // gradient fade area
          _infoRow(Icons.folder_outlined, 'Path', asset.path.isNotEmpty ? asset.path : 'Drive only'),
          _infoRow(Icons.category_outlined, 'Category',
              '${asset.effectiveCategory.displayName}${asset.hasAICategory ? ' (AI)' : ' (local)'}'),
          _infoRow(Icons.straighten, 'Size', _formatSize(asset.sizeBytes)),
          _infoRow(Icons.calendar_today, 'Created', _formatFullDate(asset.createdAt)),
          if (asset.suggestedName != null && asset.suggestedName!.isNotEmpty && asset.suggestedName != asset.name)
            _infoRow(Icons.auto_fix_high, 'Suggested name', asset.suggestedName!),
          if (asset.isBackedUp)
            _infoRow(Icons.cloud_done, 'Backup', 'Backed up to Drive'),
          if (asset.isImportant)
            _infoRow(Icons.star, 'Status', 'Marked as important'),
          if (asset.issues.isNotEmpty)
            _infoRow(Icons.warning_amber, 'Issues',
                asset.issues.map((i) => i.name).join(', ')),
          if (asset.driveFileId != null && asset.driveFileId!.isNotEmpty)
            _infoRow(Icons.cloud, 'Drive ID', asset.driveFileId!),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatFullDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Action toolbar ──────────────────────────────────────────────────────────

class _ActionToolbar extends StatelessWidget {
  final PhotoAsset asset;
  final bool isSelected;
  final bool showDeleteAction;
  final bool showKeepAction;
  final void Function(String action) onAction;

  const _ActionToolbar({
    required this.asset,
    required this.isSelected,
    required this.showDeleteAction,
    required this.showKeepAction,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = asset.path.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.black54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Quick actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (hasFile)
                _ActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: AppTheme.primary,
                  onTap: () => onAction('edit'),
                ),
              if (hasFile)
                _ActionButton(
                  icon: Icons.auto_awesome,
                  label: 'AI',
                  color: AppTheme.secondary,
                  onTap: () => onAction('ask_ai'),
                ),
              if (hasFile)
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: Colors.blue,
                  onTap: () async {
                    await Share.shareXFiles([XFile(asset.path)]);
                  },
                ),
              // Mark / Unmark important
              if (!asset.isImportant)
                _ActionButton(
                  icon: Icons.star_outline,
                  label: 'Important',
                  color: Colors.amber,
                  onTap: () => onAction('mark_important'),
                )
              else
                _ActionButton(
                  icon: Icons.star,
                  label: 'Unmark',
                  color: Colors.amber,
                  onTap: () => onAction('unmark_important'),
                ),
              if (hasFile)
                _ActionButton(
                  icon: Icons.open_in_new,
                  label: 'Open',
                  color: Colors.white70,
                  onTap: () => onAction('open_original'),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Primary action (Keep / Delete)
          if (showDeleteAction || showKeepAction)
            Row(
              children: [
                if (showKeepAction && isSelected)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onAction('deselect'),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Keep This Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (showDeleteAction && !isSelected) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onAction('select'),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Select to Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: color, fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
