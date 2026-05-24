import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/collage_template.dart';
import '../../services/collage_service.dart';
import '../../theme/app_theme.dart';

// ── Overlay data models ───────────────────────────────────────────────────

class _TextOverlay {
  String text;
  Offset position; // fractional 0..1
  double fontSize;
  Color color;
  String fontFamily;
  bool bold;
  bool italic;
  double rotation; // radians

  _TextOverlay({
    required this.text,
    this.position = const Offset(0.5, 0.5),
    this.fontSize = 24,
    this.color = Colors.white,
    this.fontFamily = 'Default',
    this.bold = false,
    this.italic = false,
    this.rotation = 0,
  });
}

class _StickerOverlay {
  String emoji;
  Offset position; // fractional 0..1
  double size;
  double rotation; // radians

  _StickerOverlay({
    required this.emoji,
    this.position = const Offset(0.5, 0.5),
    this.size = 48,
    this.rotation = 0,
  });
}

// ── Font options ──────────────────────────────────────────────────────────

const _fontFamilies = [
  'Default',
  'serif',
  'monospace',
  'cursive',
];

// ── Sticker palette ───────────────────────────────────────────────────────

const _stickerEmojis = [
  '❤️', '⭐', '🔥', '✨', '💯', '🎉', '🌟', '💖',
  '😍', '🥰', '😎', '🤩', '😂', '🥳', '🤗', '😇',
  '🌈', '🌸', '🌺', '🍀', '🦋', '🌙', '☀️', '🌊',
  '📸', '🎨', '🎵', '🎭', '👑', '💎', '🏆', '🎯',
  '❄️', '🍂', '🌻', '🌹', '💐', '🎀', '🎈', '🎊',
];

class CollageScreen extends ConsumerStatefulWidget {
  const CollageScreen({super.key});

  @override
  ConsumerState<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends ConsumerState<CollageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Template
  CollageTemplate _template = CollageTemplates.all[0];

  // Photos assigned to slots
  final Map<int, String> _slotPhotos = {};

  // Customization
  double _spacing = 8;
  double _cornerRadius = 12;
  CollageBgStyle _bgStyle = CollageBgStyles.all[0];

  // Overlays
  final List<_TextOverlay> _textOverlays = [];
  final List<_StickerOverlay> _stickerOverlays = [];
  int? _selectedTextIndex;
  int? _selectedStickerIndex;

  // Bottom panel mode
  _PanelMode _panelMode = _PanelMode.layout;

  // Rendering
  bool _isRendering = false;
  File? _renderedFile;
  final GlobalKey _previewKey = GlobalKey();

  // Gallery
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

    final assets = await albums.first.getAssetListRange(start: 0, end: 200);
    if (mounted) {
      setState(() {
        _galleryAssets = assets;
        _loadingGallery = false;
      });
    }
  }

  // ── Photo picker ────────────────────────────────────────────────────────

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
        _renderedFile = null;
      });
    }
  }

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

  void _selectTemplate(CollageTemplate t) {
    setState(() {
      _template = t;
      final excess = _slotPhotos.keys.where((k) => k >= t.photoCount).toList();
      for (final k in excess) {
        _slotPhotos.remove(k);
      }
      _renderedFile = null;
    });
  }

  // ── Text overlay management ─────────────────────────────────────────────

  void _addTextOverlay() {
    setState(() {
      _textOverlays.add(_TextOverlay(text: 'Tap to edit'));
      _selectedTextIndex = _textOverlays.length - 1;
      _selectedStickerIndex = null;
      _panelMode = _PanelMode.text;
      _renderedFile = null;
    });
  }

  void _editTextDialog(int index) async {
    final overlay = _textOverlays[index];
    final controller = TextEditingController(text: overlay.text);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Edit Text', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter text...',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _textOverlays[index].text = result;
        _renderedFile = null;
      });
    }
    controller.dispose();
  }

  void _deleteSelectedOverlay() {
    setState(() {
      if (_selectedTextIndex != null) {
        _textOverlays.removeAt(_selectedTextIndex!);
        _selectedTextIndex = null;
      } else if (_selectedStickerIndex != null) {
        _stickerOverlays.removeAt(_selectedStickerIndex!);
        _selectedStickerIndex = null;
      }
      _renderedFile = null;
    });
  }

  // ── Sticker management ──────────────────────────────────────────────────

  void _addSticker(String emoji) {
    setState(() {
      _stickerOverlays.add(_StickerOverlay(emoji: emoji));
      _selectedStickerIndex = _stickerOverlays.length - 1;
      _selectedTextIndex = null;
      _renderedFile = null;
    });
  }

  // ── Render via RepaintBoundary ──────────────────────────────────────────

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

    setState(() {
      _isRendering = true;
      _selectedTextIndex = null;
      _selectedStickerIndex = null;
    });

    // Wait for selection borders to disappear
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Preview not ready');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture');

      final dir = await Directory.systemTemp.createTemp('collage_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/collage_$timestamp.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

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

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collage'),
        actions: [
          if (_selectedTextIndex != null || _selectedStickerIndex != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              tooltip: 'Delete selected',
              onPressed: _deleteSelectedOverlay,
            ),
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
          // Mode selector row
          _buildModeSelector(),

          // Top panel (templates or controls depending on mode)
          if (_panelMode == _PanelMode.layout) ...[
            _buildCategoryTabs(),
            _buildTemplatePicker(),
          ],

          const SizedBox(height: 4),

          // Live preview
          Expanded(child: _buildPreview()),

          // Bottom panel
          _buildBottomPanel(),

          // Render button
          _buildRenderButton(),
        ],
      ),
    );
  }

  // ── Mode selector ────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    return Container(
      height: 44,
      color: AppTheme.surface,
      child: Row(
        children: _PanelMode.values.map((mode) {
          final selected = _panelMode == mode;
          final label = switch (mode) {
            _PanelMode.layout => 'Layout',
            _PanelMode.style => 'Style',
            _PanelMode.text => 'Text',
            _PanelMode.stickers => 'Stickers',
          };
          final icon = switch (mode) {
            _PanelMode.layout => Icons.grid_view,
            _PanelMode.style => Icons.palette_outlined,
            _PanelMode.text => Icons.text_fields,
            _PanelMode.stickers => Icons.emoji_emotions_outlined,
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _panelMode = mode),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? AppTheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16,
                        color: selected ? AppTheme.primary : AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(
                      fontSize: 12,
                      color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final t = templates[i];
          final selected = t.id == _template.id;
          return GestureDetector(
            onTap: () => _selectTemplate(t),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: selected
                    ? Border.all(color: AppTheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36, height: 36,
                    child: CustomPaint(
                      painter: _TemplateMiniPainter(
                        template: t,
                        color: selected ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(t.name, style: TextStyle(
                    fontSize: 8,
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Preview ─────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    if (_renderedFile != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(_renderedFile!, fit: BoxFit.contain),
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
            child: RepaintBoundary(
              key: _previewKey,
              child: Container(
                width: w, height: h,
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
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Photo slots
                    ...List.generate(_template.photoCount, (i) =>
                        _buildPhotoSlot(i, w, h)),
                    // Text overlays
                    ...List.generate(_textOverlays.length, (i) =>
                        _buildTextOverlayWidget(i, w, h)),
                    // Sticker overlays
                    ...List.generate(_stickerOverlays.length, (i) =>
                        _buildStickerOverlayWidget(i, w, h)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoSlot(int i, double w, double h) {
    final slot = _template.slots[i];
    final left = slot.x * w + _spacing / 2;
    final top = slot.y * h + _spacing / 2;
    final slotW = slot.width * w - _spacing;
    final slotH = slot.height * h - _spacing;

    if (slotW <= 0 || slotH <= 0) return const SizedBox.shrink();

    return Positioned(
      left: left, top: top, width: slotW, height: slotH,
      child: DragTarget<int>(
        onAcceptWithDetails: (d) => _swapSlots(d.data, i),
        builder: (ctx, candidateData, _) {
          final isHovered = candidateData.isNotEmpty;
          return Draggable<int>(
            data: i,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: slotW * 0.8, height: slotH * 0.8,
                child: _slotContent(i, slotW, slotH),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3, child: _slotContent(i, slotW, slotH)),
            child: GestureDetector(
              onTap: () => _pickPhotoForSlot(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  border: isHovered
                      ? Border.all(color: AppTheme.primary, width: 2)
                      : null,
                ),
                child: _slotContent(i, slotW, slotH),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slotContent(int index, double w, double h) {
    final hasPhoto = _slotPhotos.containsKey(index);
    return ClipRRect(
      borderRadius: BorderRadius.circular(_cornerRadius),
      child: hasPhoto
          ? Image.file(File(_slotPhotos[index]!),
              width: w, height: h, fit: BoxFit.cover,
              cacheWidth: 300, cacheHeight: 300)
          : Container(
              width: w, height: h,
              color: AppTheme.cardColor.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.textSecondary,
                      size: math.min(w, h) * 0.3),
                  const SizedBox(height: 4),
                  Text('${index + 1}', style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: math.min(w, h) * 0.12,
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
    );
  }

  // ── Text overlay widget ─────────────────────────────────────────────────

  Widget _buildTextOverlayWidget(int i, double w, double h) {
    final overlay = _textOverlays[i];
    final selected = _selectedTextIndex == i;
    final fontFamily = overlay.fontFamily == 'Default' ? null : overlay.fontFamily;

    return Positioned(
      left: overlay.position.dx * w - 50,
      top: overlay.position.dy * h - 20,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTextIndex = i;
            _selectedStickerIndex = null;
            _panelMode = _PanelMode.text;
          });
        },
        onDoubleTap: () => _editTextDialog(i),
        onPanUpdate: (d) {
          setState(() {
            overlay.position = Offset(
              (overlay.position.dx + d.delta.dx / w).clamp(0.05, 0.95),
              (overlay.position.dy + d.delta.dy / h).clamp(0.05, 0.95),
            );
            _renderedFile = null;
          });
        },
        child: Transform.rotate(
          angle: overlay.rotation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(color: AppTheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              overlay.text,
              style: TextStyle(
                fontSize: overlay.fontSize,
                color: overlay.color,
                fontFamily: fontFamily,
                fontWeight: overlay.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: overlay.italic ? FontStyle.italic : FontStyle.normal,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sticker overlay widget ──────────────────────────────────────────────

  Widget _buildStickerOverlayWidget(int i, double w, double h) {
    final sticker = _stickerOverlays[i];
    final selected = _selectedStickerIndex == i;

    return Positioned(
      left: sticker.position.dx * w - sticker.size / 2,
      top: sticker.position.dy * h - sticker.size / 2,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStickerIndex = i;
            _selectedTextIndex = null;
            _panelMode = _PanelMode.stickers;
          });
        },
        onPanUpdate: (d) {
          setState(() {
            sticker.position = Offset(
              (sticker.position.dx + d.delta.dx / w).clamp(0.05, 0.95),
              (sticker.position.dy + d.delta.dy / h).clamp(0.05, 0.95),
            );
            _renderedFile = null;
          });
        },
        child: Transform.rotate(
          angle: sticker.rotation,
          child: Container(
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(color: AppTheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            padding: const EdgeInsets.all(2),
            child: Text(sticker.emoji, style: TextStyle(fontSize: sticker.size)),
          ),
        ),
      ),
    );
  }

  // ── Bottom panel ────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: switch (_panelMode) {
        _PanelMode.layout => const SizedBox.shrink(),
        _PanelMode.style => _buildStylePanel(),
        _PanelMode.text => _buildTextPanel(),
        _PanelMode.stickers => _buildStickerPanel(),
      },
    );
  }

  Widget _buildStylePanel() {
    return Column(
      children: [
        // Spacing
        _sliderRow(Icons.space_bar, 'Spacing', _spacing, 0, 24, 24,
            (v) => setState(() { _spacing = v; _renderedFile = null; })),
        // Corners
        _sliderRow(Icons.rounded_corner, 'Corners', _cornerRadius, 0, 32, 32,
            (v) => setState(() { _cornerRadius = v; _renderedFile = null; })),
        // Backgrounds
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: CollageBgStyles.all.length,
            itemBuilder: (ctx, i) {
              final bg = CollageBgStyles.all[i];
              final sel = bg.color.value == _bgStyle.color.value &&
                  bg.type == _bgStyle.type;
              return GestureDetector(
                onTap: () => setState(() { _bgStyle = bg; _renderedFile = null; }),
                child: Container(
                  width: 30, height: 30,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: bg.type == CollageBgType.gradient && bg.gradientEnd != null
                        ? LinearGradient(colors: [bg.color, bg.gradientEnd!])
                        : null,
                    color: bg.type == CollageBgType.solid ? bg.color : null,
                    border: sel
                        ? Border.all(color: AppTheme.primary, width: 2.5)
                        : Border.all(color: AppTheme.textSecondary.withOpacity(0.3)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(IconData icon, String label, double value,
      double min, double max, int divisions, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        Expanded(
          child: Slider(
            value: value, min: min, max: max, divisions: divisions,
            activeColor: AppTheme.primary, onChanged: onChanged,
          ),
        ),
        SizedBox(width: 24, child: Text('${value.round()}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
      ],
    );
  }

  Widget _buildTextPanel() {
    final hasSelection = _selectedTextIndex != null;
    final overlay = hasSelection ? _textOverlays[_selectedTextIndex!] : null;

    return Column(
      children: [
        // Add text button + font picker
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _addTextOverlay,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Text', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
            ),
            if (hasSelection) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.format_bold,
                    color: overlay!.bold ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20),
                onPressed: () => setState(() {
                  overlay.bold = !overlay.bold; _renderedFile = null;
                }),
              ),
              IconButton(
                icon: Icon(Icons.format_italic,
                    color: overlay.italic ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20),
                onPressed: () => setState(() {
                  overlay.italic = !overlay.italic; _renderedFile = null;
                }),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                onPressed: () => _editTextDialog(_selectedTextIndex!),
              ),
            ],
          ],
        ),
        if (hasSelection) ...[
          // Font size slider
          _sliderRow(Icons.format_size, 'Size', overlay!.fontSize, 12, 72, 60,
              (v) => setState(() { overlay.fontSize = v; _renderedFile = null; })),
          // Font family + color
          SizedBox(
            height: 32,
            child: Row(
              children: [
                // Font picker
                ..._fontFamilies.map((f) {
                  final sel = overlay.fontFamily == f;
                  return GestureDetector(
                    onTap: () => setState(() {
                      overlay.fontFamily = f; _renderedFile = null;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary.withOpacity(0.2) : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(6),
                        border: sel ? Border.all(color: AppTheme.primary) : null,
                      ),
                      child: Text(f == 'Default' ? 'Aa' : f.substring(0, 2),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: f == 'Default' ? null : f,
                            color: sel ? AppTheme.primary : AppTheme.textSecondary,
                          )),
                    ),
                  );
                }),
                const Spacer(),
                // Color dots
                ...[Colors.white, Colors.black, Colors.red, Colors.yellow,
                    AppTheme.primary, Colors.green, Colors.pink].map((c) {
                  final sel = overlay.color.value == c.value;
                  return GestureDetector(
                    onTap: () => setState(() {
                      overlay.color = c; _renderedFile = null;
                    }),
                    child: Container(
                      width: 22, height: 22,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: c,
                        border: sel
                            ? Border.all(color: AppTheme.primary, width: 2)
                            : Border.all(color: AppTheme.textSecondary.withOpacity(0.4)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStickerPanel() {
    final hasSelection = _selectedStickerIndex != null;
    final sticker = hasSelection ? _stickerOverlays[_selectedStickerIndex!] : null;

    return Column(
      children: [
        if (hasSelection)
          _sliderRow(Icons.photo_size_select_large, 'Size', sticker!.size, 20, 96, 76,
              (v) => setState(() { sticker.size = v; _renderedFile = null; })),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stickerEmojis.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _addSticker(_stickerEmojis[i]),
              child: Container(
                width: 40, height: 40,
                margin: const EdgeInsets.only(right: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_stickerEmojis[i], style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Render button ───────────────────────────────────────────────────────

  Widget _buildRenderButton() {
    final allFilled = _slotPhotos.length == _template.photoCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity, height: 48,
        child: _renderedFile != null
            ? Row(children: [
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cardColor),
                  child: const Text('Edit'),
                ),
              ])
            : ElevatedButton.icon(
                onPressed: _isRendering ? null : allFilled ? _renderCollage : null,
                icon: _isRendering
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: Text(_isRendering
                    ? 'Rendering...'
                    : allFilled
                        ? 'Create Collage'
                        : 'Add ${_template.photoCount - _slotPhotos.length} more photo(s)'),
              ),
      ),
    );
  }
}

// ── Panel mode enum ───────────────────────────────────────────────────────

enum _PanelMode { layout, style, text, stickers }

// ── Mini template painter ─────────────────────────────────────────────────

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
        slot.x * size.width + 1, slot.y * size.height + 1,
        slot.width * size.width - 2, slot.height * size.height - 2,
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

// ── Photo picker sheet ────────────────────────────────────────────────────

class _PhotoPickerSheet extends StatelessWidget {
  final List<AssetEntity> assets;
  final bool loadingGallery;

  const _PhotoPickerSheet({required this.assets, required this.loadingGallery});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                const Text('Select Photo', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const Spacer(),
                Text('${assets.length} photos',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: loadingGallery
                  ? const Center(child: CircularProgressIndicator())
                  : assets.isEmpty
                      ? const Center(child: Text('No photos found',
                          style: TextStyle(color: AppTheme.textSecondary)))
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(4),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4, crossAxisSpacing: 2, mainAxisSpacing: 2),
                          itemCount: assets.length,
                          itemBuilder: (ctx, i) => _GalleryTile(
                            asset: assets[i],
                            onTap: (path) => Navigator.pop(context, path),
                          ),
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
    if (mounted && file != null) setState(() => _file = file);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { if (_file != null) widget.onTap(_file!.path); },
      child: _file != null
          ? Image.file(_file!, fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200)
          : Container(
              color: AppTheme.cardColor,
              child: const Center(child: SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )),
            ),
    );
  }
}
