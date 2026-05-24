import 'dart:ui';

/// A slot in a collage layout, defined as fractional coordinates (0.0–1.0).
class CollageSlot {
  final double x;
  final double y;
  final double width;
  final double height;

  const CollageSlot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Rect toRect(double canvasW, double canvasH) => Rect.fromLTWH(
        x * canvasW,
        y * canvasH,
        width * canvasW,
        height * canvasH,
      );
}

/// A predefined collage layout.
class CollageTemplate {
  final String id;
  final String name;
  final String icon;
  final int photoCount;
  final double aspectRatio; // width / height
  final List<CollageSlot> slots;

  const CollageTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.photoCount,
    required this.aspectRatio,
    required this.slots,
  });
}

/// All built-in templates.
class CollageTemplates {
  static const double gap = 0.01; // 1% gap between slots

  static const grid2x1 = CollageTemplate(
    id: 'grid_2x1',
    name: '2 Side by Side',
    icon: '⬜⬜',
    photoCount: 2,
    aspectRatio: 2.0,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 0.495, height: 1.0),
      CollageSlot(x: 0.505, y: 0.0, width: 0.495, height: 1.0),
    ],
  );

  static const grid2x1Vertical = CollageTemplate(
    id: 'grid_2x1_v',
    name: '2 Stacked',
    icon: '⬜\n⬜',
    photoCount: 2,
    aspectRatio: 0.75,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 1.0, height: 0.495),
      CollageSlot(x: 0.0, y: 0.505, width: 1.0, height: 0.495),
    ],
  );

  static const grid2x2 = CollageTemplate(
    id: 'grid_2x2',
    name: '4 Grid',
    icon: '⬜⬜\n⬜⬜',
    photoCount: 4,
    aspectRatio: 1.0,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 0.495, height: 0.495),
      CollageSlot(x: 0.505, y: 0.0, width: 0.495, height: 0.495),
      CollageSlot(x: 0.0, y: 0.505, width: 0.495, height: 0.495),
      CollageSlot(x: 0.505, y: 0.505, width: 0.495, height: 0.495),
    ],
  );

  static const grid3x1 = CollageTemplate(
    id: 'grid_3x1',
    name: '3 Column',
    icon: '⬜⬜⬜',
    photoCount: 3,
    aspectRatio: 3.0,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 0.327, height: 1.0),
      CollageSlot(x: 0.337, y: 0.0, width: 0.327, height: 1.0),
      CollageSlot(x: 0.673, y: 0.0, width: 0.327, height: 1.0),
    ],
  );

  static const feature1Left = CollageTemplate(
    id: 'feature_1_left',
    name: '1 + 2 Feature',
    icon: '🟦⬜\n🟦⬜',
    photoCount: 3,
    aspectRatio: 1.0,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 0.6, height: 1.0),
      CollageSlot(x: 0.61, y: 0.0, width: 0.39, height: 0.495),
      CollageSlot(x: 0.61, y: 0.505, width: 0.39, height: 0.495),
    ],
  );

  static const feature1Top = CollageTemplate(
    id: 'feature_1_top',
    name: '1 Top + 3 Bottom',
    icon: '🟦🟦🟦\n⬜⬜⬜',
    photoCount: 4,
    aspectRatio: 1.33,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 1.0, height: 0.6),
      CollageSlot(x: 0.0, y: 0.61, width: 0.327, height: 0.39),
      CollageSlot(x: 0.337, y: 0.61, width: 0.327, height: 0.39),
      CollageSlot(x: 0.673, y: 0.61, width: 0.327, height: 0.39),
    ],
  );

  static const grid3x2 = CollageTemplate(
    id: 'grid_3x2',
    name: '6 Grid',
    icon: '⬜⬜⬜\n⬜⬜⬜',
    photoCount: 6,
    aspectRatio: 1.5,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 0.327, height: 0.495),
      CollageSlot(x: 0.337, y: 0.0, width: 0.327, height: 0.495),
      CollageSlot(x: 0.673, y: 0.0, width: 0.327, height: 0.495),
      CollageSlot(x: 0.0, y: 0.505, width: 0.327, height: 0.495),
      CollageSlot(x: 0.337, y: 0.505, width: 0.327, height: 0.495),
      CollageSlot(x: 0.673, y: 0.505, width: 0.327, height: 0.495),
    ],
  );

  static const grid3x3 = CollageTemplate(
    id: 'grid_3x3',
    name: '9 Grid',
    icon: '⬜⬜⬜\n⬜⬜⬜\n⬜⬜⬜',
    photoCount: 9,
    aspectRatio: 1.0,
    slots: [
      CollageSlot(x: 0.0, y: 0.0, width: 0.327, height: 0.327),
      CollageSlot(x: 0.337, y: 0.0, width: 0.327, height: 0.327),
      CollageSlot(x: 0.673, y: 0.0, width: 0.327, height: 0.327),
      CollageSlot(x: 0.0, y: 0.337, width: 0.327, height: 0.327),
      CollageSlot(x: 0.337, y: 0.337, width: 0.327, height: 0.327),
      CollageSlot(x: 0.673, y: 0.337, width: 0.327, height: 0.327),
      CollageSlot(x: 0.0, y: 0.673, width: 0.327, height: 0.327),
      CollageSlot(x: 0.337, y: 0.673, width: 0.327, height: 0.327),
      CollageSlot(x: 0.673, y: 0.673, width: 0.327, height: 0.327),
    ],
  );

  static const List<CollageTemplate> all = [
    grid2x1,
    grid2x1Vertical,
    grid3x1,
    grid2x2,
    feature1Left,
    feature1Top,
    grid3x2,
    grid3x3,
  ];
}
