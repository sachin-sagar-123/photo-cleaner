import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/services.dart';
import '../../theme/app_theme.dart';
import '../editor/photo_editor_screen.dart';

/// Smart photo browser — swipe through all unreviewed photos.
/// Swipe right or tap ✓ = mark as OK (won't appear in cleanup again).
/// Swipe left or tap ✗ = mark for deletion.
/// Tap photo = zoom in.
class PhotoBrowserScreen extends ConsumerStatefulWidget {
  const PhotoBrowserScreen({super.key});

  @override
  ConsumerState<PhotoBrowserScreen> createState() =>
      _PhotoBrowserScreenState();
}

class _PhotoBrowserScreenState extends ConsumerState<PhotoBrowserScreen>
    with SingleTickerProviderStateMixin {
  List<PhotoAsset> _photos = [];
  int _currentIndex = 0;
  final Set<String> _markedForDelete = {};
  int _reviewedCount = 0;
  bool _loading = true;

  // Swipe animation
  double _dragX = 0;
  double _dragY = 0;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final db = ref.read(databaseServiceProvider);
    final photos = await db.getUnreviewedPhotos();
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  void _onSwipeRight() {
    if (_currentIndex >= _photos.length) return;
    final photo = _photos[_currentIndex];
    _markOk(photo.id);
  }

  void _onSwipeLeft() {
    if (_currentIndex >= _photos.length) return;
    final photo = _photos[_currentIndex];
    _markForDelete(photo.id);
  }

  void _markOk(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.markReviewed(id);
    setState(() {
      _reviewedCount++;
      _currentIndex++;
      _dragX = 0;
      _dragY = 0;
    });
  }

  void _markForDelete(String id) {
    setState(() {
      _markedForDelete.add(id);
      _reviewedCount++;
      _currentIndex++;
      _dragX = 0;
      _dragY = 0;
    });
  }

  void _undoLast() {
    if (_currentIndex <= 0) return;
    final prevIndex = _currentIndex - 1;
    final photo = _photos[prevIndex];
    setState(() {
      _currentIndex = prevIndex;
      _reviewedCount--;
      _markedForDelete.remove(photo.id);
    });
    // Un-review in DB
    final db = ref.read(databaseServiceProvider);
    db.markReviewed(photo.id, reviewed: false);
  }

  Future<void> _finishReview() async {
    if (_markedForDelete.isEmpty) {
      ref.invalidate(storageStatsProvider);
      ref.invalidate(unreviewedCountProvider);
      Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Delete marked photos?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Delete ${_markedForDelete.length} photo(s)? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseServiceProvider);
      for (final id in _markedForDelete) {
        final photo = _photos.where((p) => p.id == id).firstOrNull;
        if (photo != null && photo.path.isNotEmpty) {
          final file = File(photo.path);
          if (await file.exists()) await file.delete();
        }
        await db.deletePhoto(id);
      }
    } else {
      // Mark the "delete" ones as reviewed too (user chose to keep)
      final db = ref.read(databaseServiceProvider);
      await db.markAllReviewed(_markedForDelete.toList());
    }

    ref.invalidate(storageStatsProvider);
    ref.invalidate(duplicatesProvider);
    ref.invalidate(unreviewedCountProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Photo Review')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final done = _currentIndex >= _photos.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(done
            ? 'Review Complete'
            : '${_currentIndex + 1} / ${_photos.length}'),
        actions: [
          if (_currentIndex > 0)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo last',
              onPressed: _undoLast,
            ),
          if (!done)
            TextButton(
              onPressed: _finishReview,
              child: const Text('Done'),
            ),
        ],
      ),
      body: done ? _buildSummary() : _buildSwipeCard(),
    );
  }

  Widget _buildSummary() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppTheme.secondary, size: 72),
            const SizedBox(height: 20),
            Text(
              'Reviewed $_reviewedCount photos',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${_reviewedCount - _markedForDelete.length} kept · ${_markedForDelete.length} marked for deletion',
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finishReview,
                child: Text(_markedForDelete.isEmpty
                    ? 'Done'
                    : 'Delete ${_markedForDelete.length} & Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeCard() {
    final photo = _photos[_currentIndex];
    // Show next card behind current for depth effect
    final hasNext = _currentIndex + 1 < _photos.length;

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: _photos.isEmpty
              ? 0
              : _currentIndex / _photos.length,
          backgroundColor: AppTheme.surface,
          color: AppTheme.primary,
        ),

        // Swipe hint
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back,
                  color: AppTheme.error.withOpacity(0.5), size: 16),
              const SizedBox(width: 6),
              Text(
                'Swipe left to delete · right to keep',
                style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 12),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward,
                  color: AppTheme.secondary.withOpacity(0.5), size: 16),
            ],
          ),
        ),

        // Card stack
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Next card (behind) — uses small thumbnail to save memory
                if (hasNext)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.95,
                      child: _PhotoCard(
                        photo: _photos[_currentIndex + 1],
                        opacity: 0.5,
                        isBackground: true,
                      ),
                    ),
                  ),

                // Current card (draggable)
                Positioned.fill(
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        _dragX += d.delta.dx;
                        _dragY += d.delta.dy;
                      });
                    },
                    onPanEnd: (d) {
                      if (_dragX > 100) {
                        _onSwipeRight();
                      } else if (_dragX < -100) {
                        _onSwipeLeft();
                      } else {
                        setState(() {
                          _dragX = 0;
                          _dragY = 0;
                        });
                      }
                    },
                    child: Transform.translate(
                      offset: Offset(_dragX, _dragY * 0.3),
                      child: Transform.rotate(
                        angle: _dragX * 0.001,
                        child: Stack(
                          children: [
                            _PhotoCard(photo: photo),
                            // Swipe overlay
                            if (_dragX > 40)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondary
                                        .withOpacity(
                                            (_dragX / 200).clamp(0, 0.4)),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Transform.rotate(
                                      angle: -0.2,
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: AppTheme.secondary,
                                              width: 3),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text('KEEP',
                                            style: TextStyle(
                                                color:
                                                    AppTheme.secondary,
                                                fontSize: 32,
                                                fontWeight:
                                                    FontWeight.w900)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_dragX < -40)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withOpacity(
                                        (_dragX.abs() / 200)
                                            .clamp(0, 0.4)),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: Transform.rotate(
                                      angle: 0.2,
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: AppTheme.error,
                                              width: 3),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text('DELETE',
                                            style: TextStyle(
                                                color: AppTheme.error,
                                                fontSize: 32,
                                                fontWeight:
                                                    FontWeight.w900)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Delete button
              _ActionButton(
                icon: Icons.close,
                color: AppTheme.error,
                label: 'Delete',
                onTap: _onSwipeLeft,
              ),
              // Mark Important
              _ActionButton(
                icon: Icons.star_outline,
                color: Colors.amber,
                label: 'Important',
                onTap: () async {
                  final svc = ImportantService();
                  await svc.markAsImportant(photo);
                  ref.invalidate(importantPhotosProvider);
                  ref.invalidate(importantCountProvider);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${photo.name} marked as important'),
                      backgroundColor: Colors.amber.shade700,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                  _onSwipeRight(); // auto-advance
                },
              ),
              // Edit
              _ActionButton(
                icon: Icons.edit_outlined,
                color: AppTheme.primary,
                label: 'Edit',
                onTap: () async {
                  if (photo.path.isNotEmpty) {
                    await PhotoEditorScreen.open(
                      context,
                      imagePath: photo.path,
                      fileName: photo.name,
                    );
                  }
                },
              ),
              // Keep button
              _ActionButton(
                icon: Icons.check,
                color: AppTheme.secondary,
                label: 'Keep',
                onTap: _onSwipeRight,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final PhotoAsset photo;
  final double opacity;
  final bool isBackground;

  const _PhotoCard({
    required this.photo,
    this.opacity = 1.0,
    this.isBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    // Background (next) card uses small thumbnail to save memory.
    // Current card uses screen-width resolution — still much less than
    // full 12MP (4000×3000 = 36MB RGBA vs ~1080px = ~4MB RGBA).
    final screenWidth = MediaQuery.of(context).size.width.toInt();
    final decodeWidth = isBackground ? 300 : screenWidth;

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.cardColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: photo.path.isNotEmpty
            ? Image.file(
                File(photo.path),
                fit: BoxFit.contain,
                cacheWidth: decodeWidth,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image,
                      color: AppTheme.textSecondary, size: 48),
                ),
              )
            : const Center(
                child: Icon(Icons.cloud_outlined,
                    color: AppTheme.textSecondary, size: 48),
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
