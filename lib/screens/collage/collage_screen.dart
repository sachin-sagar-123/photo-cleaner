import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/collage_template.dart';
import '../../services/collage_service.dart';
import '../../theme/app_theme.dart';

class CollageScreen extends ConsumerStatefulWidget {
  const CollageScreen({super.key});

  @override
  ConsumerState<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends ConsumerState<CollageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected template
  CollageTemplate _template = CollageTemplates.all[0];

  // Photos assigned to slots (index → file path)
  final Map<int, String> _slotPhotos = {};

  // Customization
  double _spacing = 8;
  double _cornerRadius = 12;
  CollageBgStyle _bgStyle = CollageBgStyles.all[0];

  // Rendering state
  bool _isRendering = false;
  File? _renderedFile;

  // Gallery assets for photo picker
  List<AssetEntity> _galleryAssets = [];
  bool _loadingGallery = false;

  static const _categories = TemplateCategory.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Gallery loading ─────────────────────────────────────────────────────

  Future<void> _loadGallery() async {
    if (_galleryAssets.isNotEmpty || _loadingGallery) return;
    setState(() => _loadingGallery = true);

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission required')),
        );
        setState(() => _loadingGallery = false);
      }
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isEmpty) {
      if (mounted) setState(() => _loadingGallery = false);
      return;
    }

    // Load first 200 recent photos
    final assets = await albums.first.getAssetListRange(start: 0, end: 200);
    if (mounted) {
      setState(() {
        _galleryAssets = assets;
        _loadingGallery = false;
      });
    }
  }

  // ── Photo picker bottom sheet ───────────────────────────────────────────

  Future<void> _pickPhotoForSlot(int slotIndex) async {
    await _loadGallery();
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PhotoPickerSheet(
        assets: _galleryAssets,
        loadingGallery: _loadingGallery,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _slotPhotos[slotIndex] = selected;
        _renderedFile = null; // invalidate preview
      });
    }
  }

  // ── Swap slots ──────────────────────────────────────────────────────────

  void _swapSlots(int from, int to) {
    setState(() {
      final temp = _slotPhotos[from];
      _slotPhotos[from] = _slotPhotos[to]!;
      if (temp != null) {
        _slotPhotos[to] = temp;
      } else {
        _slotPhotos.remove(to);
      }
      _renderedFile = null;
    });
  }

  // ── Render collage ──────────────────────────────────────────────────────

  Future<void> _renderCollage() async {
    if (_slotPhotos.length < _template.photoCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Add ${_template.photoCount - _slotPhotos.length} more photo(s)',
          ),
        ),
      );
      return;
    }

    setState(() => _isRendering = true);

    try {
      final paths = List.generate(
        _template.photoCount,
        (i) => _slotPhotos[i]!,
      );

      final service = CollageService();
      final file = await service.renderCollage(
        template: _template,
        photoPaths: paths,
        bgStyle: _bgStyle,
        outputSize: 1080,
        borderWidth: _spacing.round(),
        borderRadius: _cornerRadius.round(),
      );

      if (mounted) setState(() => _renderedFile = file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Render failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRendering = false);
    }
  }

  // ── Save to gallery ─────────────────────────────────────────────────────

  Future<void> _saveCollage() async {
    if (_renderedFile == null) return;

    try {
      final service = CollageService();
      await service.saveToGallery(_renderedFile!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collage saved to gallery'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  // ── Template selection ──────────────────────────────────────────────────

  void _selectTemplate(CollageTemplate t) {
    setState(() {
      _template = t;
      // Keep photos that fit, remove extras
      final excess = _slotPhotos.keys
          .where((k) => k >= t.photoCount)
          .toList();
      for (final k in excess) {
        _slotPhotos.remove(k);
      }
      _renderedFile = null;
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collage'),
        actions: [
          if (_renderedFile != null)
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save to gallery',
              onPressed: _saveCollage,
            ),
        ],
      ),
      body: Column(
        children: [
          // Template category tabs
          _buildCategoryTabs(),

          // Template picker strip
          _buildTemplatePicker(),

          const SizedBox(height: 8),

          // Live preview
          Expanded(child: _buildPreview()),

          // Customization controls
          _buildControls(),

          // Render button
          _buildRenderButton(),
        ],
      ),
    );
  }

  // ── Category tabs ───────────────────────────────────────────────────────

  Widget _buildCategoryTabs() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorColor: AppTheme.primary,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: _categories.map((c) {
          final label = switch (c) {
            TemplateCategory.classic => 'Classic',
            TemplateCategory.modern => 'Modern',
            TemplateCategory.creative => 'Creative',
            TemplateCategory.story => 'Story',
          };
          return Tab(text: label);
        }).toList(),
      ),
    );
  }

  // ── Template picker ─────────────────────────────────────────────────────

  Widget _buildTemplatePicker() {
    final cat = _categories[_tabController.index];
    final templates = CollageTemplates.byCategory(cat);

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final t = templates[i];
          final selected = t.id == _template.id;
          return GestureDetector(
            onTap: () => _selectTemplate(t),
            child: Container(
              width: 64,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? Border.all(color: AppTheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mini layout preview
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CustomPaint(
                      painter: _TemplateMiniPainter(
                        template: t,
                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 9,
                      color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Live preview ────────────────────────────────────────────────────────

  Widget _buildPreview() {
    if (_renderedFile != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _renderedFile!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          final ar = _template.aspectRatio;

          double w, h;
          if (maxW / maxH > ar) {
            h = maxH;
            w = h * ar;
          } else {
            w = maxW;
            h = w / ar;
          }

          return Center(
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _bgStyle.type == CollageBgType.gradient &&
                        _bgStyle.gradientEnd != null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_bgStyle.color, _bgStyle.gradientEnd!],
                      )
                    : null,
                color: _bgStyle.type == CollageBgType.solid
                    ? _bgStyle.color
                    : null,
              ),
              child: Stack(
                children: List.generate(_template.photoCount, (i) {
                  final slot = _template.slots[i];

                  final left = slot.x * w + _spacing / 2;
                  final top = slot.y * h + _spacing / 2;
                  final slotW = slot.width * w - _spacing;
                  final slotH = slot.height * h - _spacing;

                  if (slotW <= 0 || slotH <= 0) return const SizedBox.shrink();

                  return Positioned(
                    left: left,
                    top: top,
                    width: slotW,
                    height: slotH,
                    child: DragTarget<int>(
                      onAcceptWithDetails: (details) =>
                          _swapSlots(details.data, i),
                      builder: (ctx, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;
                        return Draggable<int>(
                          data: i,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: slotW * 0.8,
                              height: slotH * 0.8,
                              child: _buildSlotContent(i, slotW, slotH, true),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _buildSlotContent(i, slotW, slotH, false),
                          ),
                          child: GestureDetector(
                            onTap: () => _pickPhotoForSlot(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(_cornerRadius),
                                border: isHovered
                                    ? Border.all(
                                        color: AppTheme.primary, width: 2)
                                    : null,
                              ),
                              child:
                                  _buildSlotContent(i, slotW, slotH, false),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotContent(int index, double w, double h, bool isFeedback) {
    final hasPhoto = _slotPhotos.containsKey(index);

    return ClipRRect(
      borderRadius: BorderRadius.circular(_cornerRadius),
      child: hasPhoto
          ? Image.file(
              File(_slotPhotos[index]!),
              width: w,
              height: h,
              fit: BoxFit.cover,
              cacheWidth: 300,
              cacheHeight: 300,
            )
          : Container(
              width: w,
              height: h,
              color: AppTheme.cardColor.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppTheme.textSecondary,
                    size: math.min(w, h) * 0.3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: math.min(w, h) * 0.12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Customization controls ──────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Spacing slider
          Row(
            children: [
              const Icon(Icons.space_bar, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text('Spacing', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _spacing,
                  min: 0,
                  max: 24,
                  divisions: 24,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() {
                    _spacing = v;
                    _renderedFile = null;
                  }),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${_spacing.round()}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),

          // Corner radius slider
          Row(
            children: [
              const Icon(Icons.rounded_corner, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text('Corners', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _cornerRadius,
                  min: 0,
                  max: 32,
                  divisions: 32,
                  activeColor: AppTheme.primary,
                  onChanged: (v) => setState(() {
                    _cornerRadius = v;
                    _renderedFile = null;
                  }),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${_cornerRadius.round()}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),

          // Background picker
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: CollageBgStyles.all.length,
              itemBuilder: (ctx, i) {
                final bg = CollageBgStyles.all[i];
                final selected = bg.color.value == _bgStyle.color.value &&
                    bg.type == _bgStyle.type;
                return GestureDetector(
                  onTap: () => setState(() {
                    _bgStyle = bg;
                    _renderedFile = null;
                  }),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: bg.type == CollageBgType.gradient &&
                              bg.gradientEnd != null
                          ? LinearGradient(
                              colors: [bg.color, bg.gradientEnd!],
                            )
                          : null,
                      color: bg.type == CollageBgType.solid ? bg.color : null,
                      border: selected
                          ? Border.all(color: AppTheme.primary, width: 2.5)
                          : Border.all(
                              color: AppTheme.textSecondary.withOpacity(0.3),
                              width: 1,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Render button ───────────────────────────────────────────────────────

  Widget _buildRenderButton() {
    final allFilled = _slotPhotos.length == _template.photoCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: _renderedFile != null
            ? Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveCollage,
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save to Gallery'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _renderedFile = null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardColor,
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              )
            : ElevatedButton.icon(
                onPressed: _isRendering
                    ? null
                    : allFilled
                        ? _renderCollage
                        : null,
                icon: _isRendering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isRendering
                      ? 'Rendering...'
                      : allFilled
                          ? 'Create Collage'
                          : 'Add ${_template.photoCount - _slotPhotos.length} more photo(s)',
                ),
              ),
      ),
    );
  }
}

// ── Mini template preview painter ─────────────────────────────────────────

class _TemplateMiniPainter extends CustomPainter {
  final CollageTemplate template;
  final Color color;

  _TemplateMiniPainter({required this.template, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

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
  bool shouldRepaint(covariant _TemplateMiniPainter old) =>
      old.template.id != template.id || old.color != color;
}

// ── Photo picker bottom sheet ─────────────────────────────────────────────

class _PhotoPickerSheet extends StatelessWidget {
  final List<AssetEntity> assets;
  final bool loadingGallery;

  const _PhotoPickerSheet({
    required this.assets,
    required this.loadingGallery,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text(
                    'Select Photo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${assets.length} photos',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: loadingGallery
                  ? const Center(child: CircularProgressIndicator())
                  : assets.isEmpty
                      ? const Center(
                          child: Text(
                            'No photos found',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: assets.length,
                          itemBuilder: (ctx, i) {
                            return _GalleryTile(
                              asset: assets[i],
                              onTap: (path) => Navigator.pop(context, path),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final AssetEntity asset;
  final ValueChanged<String> onTap;

  const _GalleryTile({required this.asset, required this.onTap});

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    final file = await widget.asset.file;
    if (mounted && file != null) {
      setState(() => _file = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_file != null) widget.onTap(_file!.path);
      },
      child: _file != null
          ? Image.file(
              _file!,
              fit: BoxFit.cover,
              cacheWidth: 200,
              cacheHeight: 200,
            )
          : Container(
              color: AppTheme.cardColor,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
    );
  }
}
