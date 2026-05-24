import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/collage_template.dart';

/// Background style for the collage.
enum CollageBackground {
  black,
  white,
  dark,
  gradient1, // purple-blue
  gradient2, // teal-green
  gradient3, // orange-pink
  blur,
}

/// Renders collages from photos using predefined templates.
class CollageService {
  /// Renders a collage to an image file.
  ///
  /// [photoPaths] must have exactly [template.photoCount] entries.
  /// [outputSize] is the width in pixels (height derived from aspect ratio).
  /// [borderWidth] is the gap between photos in pixels.
  /// [borderRadius] is the corner radius for each photo slot.
  Future<File> renderCollage({
    required CollageTemplate template,
    required List<String> photoPaths,
    CollageBackground background = CollageBackground.dark,
    int outputSize = 1080,
    int borderWidth = 8,
    int borderRadius = 12,
  }) async {
    assert(photoPaths.length == template.photoCount);

    final canvasW = outputSize;
    final canvasH = (outputSize / template.aspectRatio).round();
    final canvas = img.Image(width: canvasW, height: canvasH);

    // Fill background
    _fillBackground(canvas, background);

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
        photo = img.copyResizeCropSquare(photo,
            size: slotW > slotH ? slotW : slotH);
        photo = img.copyCrop(photo,
            x: 0, y: 0, width: slotW, height: slotH);

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

  void _fillBackground(img.Image canvas, CollageBackground bg) {
    switch (bg) {
      case CollageBackground.black:
        img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 255));
      case CollageBackground.white:
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
      case CollageBackground.dark:
        img.fill(canvas, color: img.ColorRgba8(19, 19, 31, 255));
      case CollageBackground.gradient1:
        _fillGradient(canvas, img.ColorRgba8(108, 99, 255, 255),
            img.ColorRgba8(3, 218, 198, 255));
      case CollageBackground.gradient2:
        _fillGradient(canvas, img.ColorRgba8(3, 218, 198, 255),
            img.ColorRgba8(72, 187, 120, 255));
      case CollageBackground.gradient3:
        _fillGradient(canvas, img.ColorRgba8(237, 137, 54, 255),
            img.ColorRgba8(229, 62, 62, 255));
      case CollageBackground.blur:
        img.fill(canvas, color: img.ColorRgba8(30, 30, 46, 255));
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
