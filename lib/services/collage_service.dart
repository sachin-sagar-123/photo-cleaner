import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/collage_template.dart';

/// Renders collages from photos using the template system.
class CollageService {
  /// Convert a 0.0–1.0 color component to 0–255 int.
  static int _to8(double v) => (v * 255).round().clamp(0, 255);

  /// Renders a collage to an image file.
  ///
  /// [photoPaths] must have exactly [template.photoCount] entries.
  /// [outputSize] is the width in pixels (height derived from aspect ratio).
  /// [borderWidth] is the gap between photos in pixels.
  /// [borderRadius] is the corner radius for each photo slot.
  Future<File> renderCollage({
    required CollageTemplate template,
    required List<String> photoPaths,
    CollageBgStyle bgStyle = const CollageBgStyle(),
    int outputSize = 1080,
    int borderWidth = 8,
    int borderRadius = 12,
  }) async {
    assert(photoPaths.length == template.photoCount);

    final canvasW = outputSize;
    final canvasH = (outputSize / template.aspectRatio).round();
    final canvas = img.Image(width: canvasW, height: canvasH);

    // Fill background
    _fillBackground(canvas, bgStyle);

    // Draw each photo into its slot
    for (int i = 0; i < template.slots.length; i++) {
      final slot = template.slots[i];
      final path = photoPaths[i];

      final slotX = (slot.x * canvasW).round() + borderWidth ~/ 2;
      final slotY = (slot.y * canvasH).round() + borderWidth ~/ 2;
      final slotW = (slot.width * canvasW).round() - borderWidth;
      final slotH = (slot.height * canvasH).round() - borderWidth;

      if (slotW <= 0 || slotH <= 0) continue;

      try {
        final bytes = await File(path).readAsBytes();
        var photo = img.decodeImage(bytes);
        if (photo == null) continue;

        // Crop-fit the photo to the slot dimensions
        photo = _cropFit(photo, slotW, slotH);

        // Apply border radius mask if needed
        if (borderRadius > 0) {
          _applyRoundedCorners(photo, borderRadius);
        }

        // Composite onto canvas
        img.compositeImage(canvas, photo, dstX: slotX, dstY: slotY);
      } catch (_) {
        // Draw placeholder for failed images
        img.fillRect(canvas,
            x1: slotX,
            y1: slotY,
            x2: slotX + slotW,
            y2: slotY + slotH,
            color: img.ColorRgba8(60, 60, 80, 255));
      }
    }

    // Encode and save
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outPath = p.join(dir.path, 'collage_$timestamp.jpg');
    final encoded = img.encodeJpg(canvas, quality: 92);
    final file = File(outPath);
    await file.writeAsBytes(encoded);
    return file;
  }

  /// Saves a collage to the device gallery directory.
  Future<File> saveToGallery(File collageFile) async {
    final dir = await getExternalStorageDirectory();
    final galleryDir = Directory(p.join(dir!.path, 'PhotoCleaner', 'Collages'));
    if (!await galleryDir.exists()) {
      await galleryDir.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dest = p.join(galleryDir.path, 'collage_$timestamp.jpg');
    return collageFile.copy(dest);
  }

  /// Crop-fit: resize and center-crop to exactly fill the target dimensions.
  img.Image _cropFit(img.Image src, int targetW, int targetH) {
    final srcAR = src.width / src.height;
    final targetAR = targetW / targetH;

    int resizeW, resizeH;
    if (srcAR > targetAR) {
      // Source is wider — fit height, crop width
      resizeH = targetH;
      resizeW = (targetH * srcAR).round();
    } else {
      // Source is taller — fit width, crop height
      resizeW = targetW;
      resizeH = (targetW / srcAR).round();
    }

    var resized = img.copyResize(src, width: resizeW, height: resizeH);

    // Center crop
    final cropX = (resizeW - targetW) ~/ 2;
    final cropY = (resizeH - targetH) ~/ 2;
    return img.copyCrop(resized,
        x: cropX, y: cropY, width: targetW, height: targetH);
  }

  /// Apply rounded corners by making corner pixels transparent.
  void _applyRoundedCorners(img.Image image, int radius) {
    final r = math.min(radius, math.min(image.width, image.height) ~/ 2);
    final transparent = img.ColorRgba8(0, 0, 0, 0);

    for (int y = 0; y < r; y++) {
      for (int x = 0; x < r; x++) {
        final dx = r - x - 1;
        final dy = r - y - 1;
        if (dx * dx + dy * dy > r * r) {
          // Top-left
          image.setPixel(x, y, transparent);
          // Top-right
          image.setPixel(image.width - 1 - x, y, transparent);
          // Bottom-left
          image.setPixel(x, image.height - 1 - y, transparent);
          // Bottom-right
          image.setPixel(image.width - 1 - x, image.height - 1 - y, transparent);
        }
      }
    }
  }

  void _fillBackground(img.Image canvas, CollageBgStyle bg) {
    switch (bg.type) {
      case CollageBgType.solid:
        final c = bg.color;
        img.fill(canvas,
            color: img.ColorRgba8(_to8(c.r), _to8(c.g), _to8(c.b), _to8(c.a)));
      case CollageBgType.gradient:
        final end = bg.gradientEnd ?? bg.color;
        _fillGradient(
          canvas,
          img.ColorRgba8(_to8(bg.color.r), _to8(bg.color.g), _to8(bg.color.b), 255),
          img.ColorRgba8(_to8(end.r), _to8(end.g), _to8(end.b), 255),
        );
      case CollageBgType.pattern:
        // Fallback to solid
        final c = bg.color;
        img.fill(canvas,
            color: img.ColorRgba8(_to8(c.r), _to8(c.g), _to8(c.b), _to8(c.a)));
    }
  }

  void _fillGradient(img.Image canvas, img.Color top, img.Color bottom) {
    final topR = top.r.toInt(), topG = top.g.toInt(), topB = top.b.toInt();
    final botR = bottom.r.toInt(),
        botG = bottom.g.toInt(),
        botB = bottom.b.toInt();
    for (int y = 0; y < canvas.height; y++) {
      final t = y / canvas.height;
      final r = (topR + (botR - topR) * t).round();
      final g = (topG + (botG - topG) * t).round();
      final b = (topB + (botB - topB) * t).round();
      final color = img.ColorRgba8(r, g, b, 255);
      for (int x = 0; x < canvas.width; x++) {
        canvas.setPixel(x, y, color);
      }
    }
  }
}
