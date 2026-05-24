import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/collage_service.dart';
import '../../theme/app_theme.dart';

class CollageScreen extends ConsumerStatefulWidget {
  const CollageScreen({super.key});

  @override
  ConsumerState<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends ConsumerState<CollageScreen>
    with TickerProviderStateMixin {
  CollageTemplate _selectedTemplate = CollageTemplates.all[0];
  final List<String> _selectedPhotos = [];
  CollageBackground _background = CollageBackground.dark;
  File? _renderedCollage;
  bool _rendering = false;
  bool _saving = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectTemplate(CollageTemplate template) {
    setState(() {
      _selectedTemplate = template;
      // Trim or pad photo selection to match template
      while (_selectedPhotos.length > template.photoCount) {
        _selectedPhotos.removeLast();
      }
      _renderedCollage = null;
    });
  }

  void _togglePhoto(String path) {
    setState(() {
      if (_selectedPhotos.contains(path)) {
        _selectedPhotos.remove(path);
      } else if (_selectedPhotos.length < _selectedTemplate.photoCount) {
        _selectedPhotos.add(path);
      }
      _renderedCollage = null;
    });
  }

  Future<void> _renderPreview() async {
    if (_selectedPhotos.length != _selectedTemplate.photoCount) return;
    setState(() => _rendering = true);

    try {
      final service = CollageService();
      final file = await service.renderCollage(
        template: _selectedTemplate,
        photoPaths: _selectedPhotos,
        background: _background,
        outputSize: 1080,
      );
      setState(() => _renderedCollage = file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to render: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _rendering = false);
    }
  }

  Future<void> _saveCollage() async {
    if (_renderedCollage == null) return;
    setState(() => _saving = true);

    try {
      final service = CollageService();
      await service.saveToGallery(_renderedCollage!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Collage saved to gallery'),
              ],
            ),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photosReady =
        _selectedPhotos.length == _selectedTemplate.photoCount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Collage'),
        actions: [
          if (_renderedCollage != null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt),
              tooltip: 'Save to gallery',
              onPressed: _saving ? null : _saveCollage,
            ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(child: _buildPreviewArea(photosReady)),

          // Bottom controls
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Template selector
                _buildTemplateSelector(),

                // Background selector
                _buildBackgroundSelector(),

                // Photo selector
                _buildPhotoSelector(),

                // Generate button
                _buildGenerateButton(photosReady),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(bool photosReady) {
    if (_rendering) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Rendering collage...',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    if (_renderedCollage != null) {
      return GestureDetector(
        onTap: () => _showFullPreview(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _renderedCollage!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    // Template preview with slots
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: _selectedTemplate.aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.2),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: List.generate(
                      _selectedTemplate.slots.length, (i) {
                    final slot = _selectedTemplate.slots[i];
                    final hasPhoto = i < _selectedPhotos.length;
                    final rect = slot.toRect(
                        constraints.maxWidth, constraints.maxHeight);

                    return Positioned(
                      left: rect.left + 3,
                      top: rect.top + 3,
                      width: rect.width - 6,
                      height: rect.height - 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: hasPhoto
                            ? Image.file(
                                File(_selectedPhotos[i]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _emptySlot(i + 1),
                              )
                            : _emptySlot(i + 1),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptySlot(int number) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final opacity =
            0.05 + (_pulseController.value * 0.08);
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(opacity),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: AppTheme.primary.withOpacity(0.5),
                    size: 24),
                const SizedBox(height: 4),
                Text(
                  '$number',
                  style: TextStyle(
                    color: AppTheme.primary.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('LAYOUT',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: CollageTemplates.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = CollageTemplates.all[i];
              final selected = t.id == _selectedTemplate.id;
              return GestureDetector(
                onTap: () => _selectTemplate(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TemplateIcon(
                          template: t,
                          selected: selected,
                          size: 28),
                      const SizedBox(height: 2),
                      Text(
                        '${t.photoCount}',
                        style: TextStyle(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundSelector() {
    final backgrounds = CollageBackground.values;
    final labels = {
      CollageBackground.black: ('Black', Colors.black),
      CollageBackground.white: ('White', Colors.white),
      CollageBackground.dark: ('Dark', const Color(0xFF13131F)),
      CollageBackground.gradient1: ('Purple', AppTheme.primary),
      CollageBackground.gradient2: ('Teal', AppTheme.secondary),
      CollageBackground.gradient3: ('Warm', Colors.orange),
      CollageBackground.blur: ('Blur', Colors.grey),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('BACKGROUND',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: backgrounds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final bg = backgrounds[i];
              final selected = bg == _background;
              final info = labels[bg]!;
              return GestureDetector(
                onTap: () => setState(() {
                  _background = bg;
                  _renderedCollage = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: info.$2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white24,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        info.$1,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSelector() {
    final photosAsync = ref.watch(photosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text('SELECT PHOTOS',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const Spacer(),
              Text(
                '${_selectedPhotos.length} / ${_selectedTemplate.photoCount}',
                style: TextStyle(
                  color: _selectedPhotos.length ==
                          _selectedTemplate.photoCount
                      ? AppTheme.secondary
                      : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: photosAsync.when(
            data: (photos) {
              final localPhotos =
                  photos.where((p) => p.path.isNotEmpty).toList();
              if (localPhotos.isEmpty) {
                return const Center(
                  child: Text('No photos found. Scan first.',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12)),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: localPhotos.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final photo = localPhotos[i];
                  final idx =
                      _selectedPhotos.indexOf(photo.path);
                  final isSelected = idx >= 0;

                  return GestureDetector(
                    onTap: () => _togglePhoto(photo.path),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(8),
                            child: Image.file(
                              File(photo.path),
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (_, __, ___) =>
                                  Container(
                                color: AppTheme.cardColor,
                                child: const Icon(
                                    Icons.broken_image,
                                    color:
                                        AppTheme.textSecondary,
                                    size: 20),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Center(
                child: Text('Error loading photos',
                    style: TextStyle(color: AppTheme.error))),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton(bool photosReady) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: photosReady
                ? const LinearGradient(
                    colors: [AppTheme.primary, Color(0xFF03DAC6)],
                  )
                : null,
            color: photosReady ? null : AppTheme.cardColor,
          ),
          child: ElevatedButton.icon(
            onPressed: photosReady && !_rendering
                ? _renderPreview
                : null,
            icon: _rendering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _renderedCollage != null
                        ? Icons.refresh
                        : Icons.auto_awesome,
                    size: 20),
            label: Text(
              _renderedCollage != null
                  ? 'Regenerate'
                  : photosReady
                      ? 'Create Collage'
                      : 'Select ${_selectedTemplate.photoCount - _selectedPhotos.length} more photo${_selectedTemplate.photoCount - _selectedPhotos.length != 1 ? "s" : ""}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: AppTheme.textSecondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullPreview(BuildContext context) {
    if (_renderedCollage == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullPreview(
          file: _renderedCollage!,
          onSave: _saveCollage,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

// ── Template icon mini-preview ──────────────────────────────────────────

class _TemplateIcon extends StatelessWidget {
  final CollageTemplate template;
  final bool selected;
  final double size;

  const _TemplateIcon({
    required this.template,
    required this.selected,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppTheme.primary : AppTheme.textSecondary;
    return SizedBox(
      width: size,
      height: size / template.aspectRatio,
      child: CustomPaint(
        painter: _TemplateIconPainter(
          template: template,
          color: color,
        ),
      ),
    );
  }
}

class _TemplateIconPainter extends CustomPainter {
  final CollageTemplate template;
  final Color color;

  _TemplateIconPainter({required this.template, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final slot in template.slots) {
      final rect = Rect.fromLTWH(
        slot.x * size.width + 1,
        slot.y * size.height + 1,
        slot.width * size.width - 2,
        slot.height * size.height - 2,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
      canvas.drawRRect(rrect, paint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TemplateIconPainter old) =>
      old.template.id != template.id || old.color != color;
}

// ── Full-screen preview ─────────────────────────────────────────────────

class _FullPreview extends StatelessWidget {
  final File file;
  final VoidCallback onSave;

  const _FullPreview({required this.file, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      onSave();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(file, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
