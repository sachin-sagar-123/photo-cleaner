import 'dart:ui';

/// A sticker/emoji overlay on a collage.
class StickerOverlay {
  String emoji;
  Offset position; // fractional 0..1
  double size;
  double rotation;

  StickerOverlay({
    required this.emoji,
    this.position = const Offset(0.5, 0.5),
    this.size = 48,
    this.rotation = 0,
  });

  StickerOverlay copyWith({
    String? emoji,
    Offset? position,
    double? size,
    double? rotation,
  }) => StickerOverlay(
    emoji: emoji ?? this.emoji,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
  );
}
