import 'dart:ui';

/// A slot in a collage layout, defined as fractional coordinates (0.0–1.0).
class CollageSlot {
  final double x;
  final double y;
  final double width;
  final double height;

  /// Border radius for this slot (0 = sharp corners).
  final double borderRadius;

  const CollageSlot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.borderRadius = 0,
  });

  Rect toRect(double canvasWidth, double canvasHeight) {
    return Rect.fromLTWH(
      x * canvasWidth,
      y * canvasHeight,
      width * canvasWidth,
      height * canvasHeight,
    );
  }
}

/// Background style for the collage.
enum CollageBgType { solid, gradient, pattern }

class CollageBgStyle {
  final CollageBgType type;
  final Color color;
  final Color? gradientEnd;
  final String? patternName;

  const CollageBgStyle({
    this.type = CollageBgType.solid,
    this.color = const Color(0xFF1A1A2E),
    this.gradientEnd,
    this.patternName,
  });
}

/// Category for organizing templates in the UI.
enum TemplateCategory {
  classic,
  modern,
  creative,
  story,
}

class CollageTemplate {
  final String id;
  final String name;
  final TemplateCategory category;
  final List<CollageSlot> slots;
  final double aspectRatio; // width / height
  final String icon; // emoji for template picker

  const CollageTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.slots,
    this.aspectRatio = 1.0,
    this.icon = '⬜',
  });

  int get photoCount => slots.length;
}

/// All available collage templates — 24 modern layouts.
class CollageTemplates {
  static const List<CollageTemplate> all = [
    // ── Classic (2-photo) ─────────────────────────────────────────────────
    _classic2Vertical,
    _classic2Horizontal,
    _classic2DiagonalLeft,
    _classic2DiagonalRight,

    // ── Classic (3-photo) ─────────────────────────────────────────────────
    _classic3TopHeavy,
    _classic3BottomHeavy,
    _classic3LeftHeavy,
    _classic3Triptych,

    // ── Modern (4-photo) ──────────────────────────────────────────────────
    _modern4Grid,
    _modern4LShape,
    _modern4TShape,
    _modern4Mosaic,
    _modern4Diamond,

    // ── Creative (5-photo) ────────────────────────────────────────────────
    _creative5Cross,
    _creative5Staircase,
    _creative5Feature,
    _creative5Mosaic,

    // ── Story (6+ photo) ──────────────────────────────────────────────────
    _story6Grid,
    _story6Magazine,
    _story6Mosaic,
    _story7Feature,
    _story8Grid,
    _story9Grid,

    // ── Special ───────────────────────────────────────────────────────────
    _specialPanorama,
    _specialStoryStrip,
  ];

  // ── 2-photo layouts ─────────────────────────────────────────────────────

  static const _classic2Vertical = CollageTemplate(
    id: '2v', name: 'Side by Side', category: TemplateCategory.classic,
    icon: '▮▮',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.5, height: 1),
      CollageSlot(x: 0.5, y: 0, width: 0.5, height: 1),
    ],
  );

  static const _classic2Horizontal = CollageTemplate(
    id: '2h', name: 'Stacked', category: TemplateCategory.classic,
    icon: '▬▬',
    slots: [
      CollageSlot(x: 0, y: 0, width: 1, height: 0.5),
      CollageSlot(x: 0, y: 0.5, width: 1, height: 0.5),
    ],
  );

  static const _classic2DiagonalLeft = CollageTemplate(
    id: '2dl', name: 'Diagonal Left', category: TemplateCategory.classic,
    icon: '◣◥',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.55, height: 0.55),
      CollageSlot(x: 0.45, y: 0.45, width: 0.55, height: 0.55),
    ],
  );

  static const _classic2DiagonalRight = CollageTemplate(
    id: '2dr', name: 'Diagonal Right', category: TemplateCategory.classic,
    icon: '◢◤',
    slots: [
      CollageSlot(x: 0.45, y: 0, width: 0.55, height: 0.55),
      CollageSlot(x: 0, y: 0.45, width: 0.55, height: 0.55),
    ],
  );

  // ── 3-photo layouts ─────────────────────────────────────────────────────

  static const _classic3TopHeavy = CollageTemplate(
    id: '3th', name: 'Top Feature', category: TemplateCategory.classic,
    icon: '▬▮▮',
    slots: [
      CollageSlot(x: 0, y: 0, width: 1, height: 0.55),
      CollageSlot(x: 0, y: 0.55, width: 0.5, height: 0.45),
      CollageSlot(x: 0.5, y: 0.55, width: 0.5, height: 0.45),
    ],
  );

  static const _classic3BottomHeavy = CollageTemplate(
    id: '3bh', name: 'Bottom Feature', category: TemplateCategory.classic,
    icon: '▮▮▬',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.5, height: 0.45),
      CollageSlot(x: 0.5, y: 0, width: 0.5, height: 0.45),
      CollageSlot(x: 0, y: 0.45, width: 1, height: 0.55),
    ],
  );

  static const _classic3LeftHeavy = CollageTemplate(
    id: '3lh', name: 'Left Feature', category: TemplateCategory.classic,
    icon: '▮▬▬',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.55, height: 1),
      CollageSlot(x: 0.55, y: 0, width: 0.45, height: 0.5),
      CollageSlot(x: 0.55, y: 0.5, width: 0.45, height: 0.5),
    ],
  );

  static const _classic3Triptych = CollageTemplate(
    id: '3tri', name: 'Triptych', category: TemplateCategory.classic,
    icon: '▮▮▮',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.333, height: 1),
      CollageSlot(x: 0.333, y: 0, width: 0.334, height: 1),
      CollageSlot(x: 0.667, y: 0, width: 0.333, height: 1),
    ],
  );

  // ── 4-photo layouts ─────────────────────────────────────────────────────

  static const _modern4Grid = CollageTemplate(
    id: '4g', name: 'Grid', category: TemplateCategory.modern,
    icon: '⊞',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.5, height: 0.5),
      CollageSlot(x: 0.5, y: 0, width: 0.5, height: 0.5),
      CollageSlot(x: 0, y: 0.5, width: 0.5, height: 0.5),
      CollageSlot(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
    ],
  );

  static const _modern4LShape = CollageTemplate(
    id: '4l', name: 'L-Shape', category: TemplateCategory.modern,
    icon: '⌐',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.6, height: 0.6),
      CollageSlot(x: 0.6, y: 0, width: 0.4, height: 0.6),
      CollageSlot(x: 0, y: 0.6, width: 0.4, height: 0.4),
      CollageSlot(x: 0.4, y: 0.6, width: 0.6, height: 0.4),
    ],
  );

  static const _modern4TShape = CollageTemplate(
    id: '4t', name: 'T-Shape', category: TemplateCategory.modern,
    icon: '⊤',
    slots: [
      CollageSlot(x: 0, y: 0, width: 1, height: 0.45),
      CollageSlot(x: 0, y: 0.45, width: 0.333, height: 0.55),
      CollageSlot(x: 0.333, y: 0.45, width: 0.334, height: 0.55),
      CollageSlot(x: 0.667, y: 0.45, width: 0.333, height: 0.55),
    ],
  );

  static const _modern4Mosaic = CollageTemplate(
    id: '4m', name: 'Mosaic', category: TemplateCategory.modern,
    icon: '◫',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.65, height: 0.65),
      CollageSlot(x: 0.65, y: 0, width: 0.35, height: 0.35),
      CollageSlot(x: 0.65, y: 0.35, width: 0.35, height: 0.65),
      CollageSlot(x: 0, y: 0.65, width: 0.65, height: 0.35),
    ],
  );

  static const _modern4Diamond = CollageTemplate(
    id: '4d', name: 'Diamond', category: TemplateCategory.modern,
    icon: '◇',
    slots: [
      CollageSlot(x: 0.25, y: 0, width: 0.5, height: 0.35),
      CollageSlot(x: 0, y: 0.25, width: 0.5, height: 0.5),
      CollageSlot(x: 0.5, y: 0.25, width: 0.5, height: 0.5),
      CollageSlot(x: 0.25, y: 0.65, width: 0.5, height: 0.35),
    ],
  );

  // ── 5-photo layouts ─────────────────────────────────────────────────────

  static const _creative5Cross = CollageTemplate(
    id: '5c', name: 'Cross', category: TemplateCategory.creative,
    icon: '✚',
    slots: [
      CollageSlot(x: 0.3, y: 0, width: 0.4, height: 0.3),
      CollageSlot(x: 0, y: 0.3, width: 0.3, height: 0.4),
      CollageSlot(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
      CollageSlot(x: 0.7, y: 0.3, width: 0.3, height: 0.4),
      CollageSlot(x: 0.3, y: 0.7, width: 0.4, height: 0.3),
    ],
  );

  static const _creative5Staircase = CollageTemplate(
    id: '5s', name: 'Staircase', category: TemplateCategory.creative,
    icon: '⋰',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.4, height: 0.35),
      CollageSlot(x: 0.4, y: 0.1, width: 0.35, height: 0.35),
      CollageSlot(x: 0.15, y: 0.35, width: 0.35, height: 0.35),
      CollageSlot(x: 0.55, y: 0.45, width: 0.45, height: 0.35),
      CollageSlot(x: 0, y: 0.65, width: 0.55, height: 0.35),
    ],
  );

  static const _creative5Feature = CollageTemplate(
    id: '5f', name: 'Feature', category: TemplateCategory.creative,
    icon: '▣',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.6, height: 1),
      CollageSlot(x: 0.6, y: 0, width: 0.4, height: 0.25),
      CollageSlot(x: 0.6, y: 0.25, width: 0.4, height: 0.25),
      CollageSlot(x: 0.6, y: 0.5, width: 0.4, height: 0.25),
      CollageSlot(x: 0.6, y: 0.75, width: 0.4, height: 0.25),
    ],
  );

  static const _creative5Mosaic = CollageTemplate(
    id: '5m', name: 'Mosaic 5', category: TemplateCategory.creative,
    icon: '⊞⊞',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.5, height: 0.5),
      CollageSlot(x: 0.5, y: 0, width: 0.5, height: 0.3),
      CollageSlot(x: 0.5, y: 0.3, width: 0.5, height: 0.35),
      CollageSlot(x: 0, y: 0.5, width: 0.35, height: 0.5),
      CollageSlot(x: 0.35, y: 0.65, width: 0.65, height: 0.35),
    ],
  );

  // ── 6+ photo layouts ────────────────────────────────────────────────────

  static const _story6Grid = CollageTemplate(
    id: '6g', name: 'Grid 6', category: TemplateCategory.story,
    icon: '⊞⊞⊞',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.333, height: 0.5),
      CollageSlot(x: 0.333, y: 0, width: 0.334, height: 0.5),
      CollageSlot(x: 0.667, y: 0, width: 0.333, height: 0.5),
      CollageSlot(x: 0, y: 0.5, width: 0.333, height: 0.5),
      CollageSlot(x: 0.333, y: 0.5, width: 0.334, height: 0.5),
      CollageSlot(x: 0.667, y: 0.5, width: 0.333, height: 0.5),
    ],
  );

  static const _story6Magazine = CollageTemplate(
    id: '6mag', name: 'Magazine', category: TemplateCategory.story,
    icon: '📰',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.65, height: 0.5),
      CollageSlot(x: 0.65, y: 0, width: 0.35, height: 0.25),
      CollageSlot(x: 0.65, y: 0.25, width: 0.35, height: 0.25),
      CollageSlot(x: 0, y: 0.5, width: 0.35, height: 0.5),
      CollageSlot(x: 0.35, y: 0.5, width: 0.35, height: 0.5),
      CollageSlot(x: 0.7, y: 0.5, width: 0.3, height: 0.5),
    ],
  );

  static const _story6Mosaic = CollageTemplate(
    id: '6mos', name: 'Mosaic 6', category: TemplateCategory.story,
    icon: '🧩',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.5, height: 0.4),
      CollageSlot(x: 0.5, y: 0, width: 0.5, height: 0.6),
      CollageSlot(x: 0, y: 0.4, width: 0.3, height: 0.3),
      CollageSlot(x: 0.3, y: 0.4, width: 0.2, height: 0.6),
      CollageSlot(x: 0, y: 0.7, width: 0.3, height: 0.3),
      CollageSlot(x: 0.5, y: 0.6, width: 0.5, height: 0.4),
    ],
  );

  static const _story7Feature = CollageTemplate(
    id: '7f', name: 'Feature 7', category: TemplateCategory.story,
    icon: '🌟',
    aspectRatio: 1.0,
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.5, height: 0.5),
      CollageSlot(x: 0.5, y: 0, width: 0.25, height: 0.25),
      CollageSlot(x: 0.75, y: 0, width: 0.25, height: 0.25),
      CollageSlot(x: 0.5, y: 0.25, width: 0.5, height: 0.25),
      CollageSlot(x: 0, y: 0.5, width: 0.333, height: 0.5),
      CollageSlot(x: 0.333, y: 0.5, width: 0.334, height: 0.5),
      CollageSlot(x: 0.667, y: 0.5, width: 0.333, height: 0.5),
    ],
  );

  static const _story8Grid = CollageTemplate(
    id: '8g', name: 'Grid 8', category: TemplateCategory.story,
    icon: '⊞⊞⊞⊞',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.25, height: 0.5),
      CollageSlot(x: 0.25, y: 0, width: 0.25, height: 0.5),
      CollageSlot(x: 0.5, y: 0, width: 0.25, height: 0.5),
      CollageSlot(x: 0.75, y: 0, width: 0.25, height: 0.5),
      CollageSlot(x: 0, y: 0.5, width: 0.25, height: 0.5),
      CollageSlot(x: 0.25, y: 0.5, width: 0.25, height: 0.5),
      CollageSlot(x: 0.5, y: 0.5, width: 0.25, height: 0.5),
      CollageSlot(x: 0.75, y: 0.5, width: 0.25, height: 0.5),
    ],
  );

  static const _story9Grid = CollageTemplate(
    id: '9g', name: 'Grid 9', category: TemplateCategory.story,
    icon: '⊞⊞⊞⊞⊞',
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.333, height: 0.333),
      CollageSlot(x: 0.333, y: 0, width: 0.334, height: 0.333),
      CollageSlot(x: 0.667, y: 0, width: 0.333, height: 0.333),
      CollageSlot(x: 0, y: 0.333, width: 0.333, height: 0.334),
      CollageSlot(x: 0.333, y: 0.333, width: 0.334, height: 0.334),
      CollageSlot(x: 0.667, y: 0.333, width: 0.333, height: 0.334),
      CollageSlot(x: 0, y: 0.667, width: 0.333, height: 0.333),
      CollageSlot(x: 0.333, y: 0.667, width: 0.334, height: 0.333),
      CollageSlot(x: 0.667, y: 0.667, width: 0.333, height: 0.333),
    ],
  );

  // ── Special layouts ─────────────────────────────────────────────────────

  static const _specialPanorama = CollageTemplate(
    id: 'pan', name: 'Panorama', category: TemplateCategory.creative,
    icon: '🌅',
    aspectRatio: 2.0,
    slots: [
      CollageSlot(x: 0, y: 0, width: 0.333, height: 1),
      CollageSlot(x: 0.333, y: 0, width: 0.334, height: 1),
      CollageSlot(x: 0.667, y: 0, width: 0.333, height: 1),
    ],
  );

  static const _specialStoryStrip = CollageTemplate(
    id: 'strip', name: 'Story Strip', category: TemplateCategory.story,
    icon: '🎞️',
    aspectRatio: 0.45,
    slots: [
      CollageSlot(x: 0, y: 0, width: 1, height: 0.25),
      CollageSlot(x: 0, y: 0.25, width: 1, height: 0.25),
      CollageSlot(x: 0, y: 0.5, width: 1, height: 0.25),
      CollageSlot(x: 0, y: 0.75, width: 1, height: 0.25),
    ],
  );

  /// Get templates filtered by photo count.
  static List<CollageTemplate> forPhotoCount(int count) {
    return all.where((t) => t.photoCount <= count).toList();
  }

  /// Get templates by category.
  static List<CollageTemplate> byCategory(TemplateCategory cat) {
    return all.where((t) => t.category == cat).toList();
  }
}

/// Predefined background styles.
class CollageBgStyles {
  static const List<CollageBgStyle> all = [
    CollageBgStyle(color: Color(0xFF1A1A2E)),           // Dark navy
    CollageBgStyle(color: Color(0xFF000000)),           // Black
    CollageBgStyle(color: Color(0xFFFFFFFF)),           // White
    CollageBgStyle(color: Color(0xFF2D2D2D)),           // Dark gray
    CollageBgStyle(color: Color(0xFFF5F5DC)),           // Beige
    CollageBgStyle(color: Color(0xFFE8D5B7)),           // Cream
    CollageBgStyle(color: Color(0xFF1B4332)),           // Forest green
    CollageBgStyle(color: Color(0xFF3D0C11)),           // Dark red
    CollageBgStyle(color: Color(0xFF0D1B2A)),           // Navy
    CollageBgStyle(color: Color(0xFF2B2D42)),           // Slate
    // Gradients
    CollageBgStyle(
      type: CollageBgType.gradient,
      color: Color(0xFF667EEA),
      gradientEnd: Color(0xFF764BA2),
    ),
    CollageBgStyle(
      type: CollageBgType.gradient,
      color: Color(0xFFF093FB),
      gradientEnd: Color(0xFFF5576C),
    ),
    CollageBgStyle(
      type: CollageBgType.gradient,
      color: Color(0xFF4FACFE),
      gradientEnd: Color(0xFF00F2FE),
    ),
    CollageBgStyle(
      type: CollageBgType.gradient,
      color: Color(0xFF43E97B),
      gradientEnd: Color(0xFF38F9D7),
    ),
    CollageBgStyle(
      type: CollageBgType.gradient,
      color: Color(0xFFFA709A),
      gradientEnd: Color(0xFFFEE140),
    ),
    CollageBgStyle(
      type: CollageBgType.gradient,
      color: Color(0xFF0C0C0C),
      gradientEnd: Color(0xFF2D2D2D),
    ),
  ];
}
