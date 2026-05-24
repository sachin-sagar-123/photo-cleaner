import 'dart:ui';

/// A text overlay on a collage.
class TextOverlay {
  String text;
  Offset position; // fractional 0..1
  double fontSize;
  Color color;
  String fontFamily;
  bool bold;
  bool italic;
  double rotation;

  TextOverlay({
    required this.text,
    this.position = const Offset(0.5, 0.5),
    this.fontSize = 24,
    this.color = const Color(0xFFFFFFFF),
    this.fontFamily = 'Default',
    this.bold = false,
    this.italic = false,
    this.rotation = 0,
  });

  TextOverlay copyWith({
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
    String? fontFamily,
    bool? bold,
    bool? italic,
    double? rotation,
  }) => TextOverlay(
    text: text ?? this.text,
    position: position ?? this.position,
    fontSize: fontSize ?? this.fontSize,
    color: color ?? this.color,
    fontFamily: fontFamily ?? this.fontFamily,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    rotation: rotation ?? this.rotation,
  );
}
