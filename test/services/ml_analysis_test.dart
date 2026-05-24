import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/services/ml_analysis_service.dart';

Uint8List _makeJpeg({
  required int width,
  required int height,
  required int r,
  required int g,
  required int b,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Creates a blurry image by heavily downsampling then upsampling.
Uint8List _blurryJpeg() {
  final image = img.Image(width: 400, height: 400);
  // Gradient to give it some content
  for (int y = 0; y < 400; y++) {
    for (int x = 0; x < 400; x++) {
      image.setPixelRgb(x, y, x ~/ 2, y ~/ 2, 100);
    }
  }
  // Simulate blur: apply Gaussian blur multiple times
  var blurred = img.gaussianBlur(image, radius: 20);
  blurred = img.gaussianBlur(blurred, radius: 20);
  return Uint8List.fromList(img.encodeJpg(blurred, quality: 90));
}

/// Creates a sharp image with high-frequency edges.
Uint8List _sharpJpeg() {
  final image = img.Image(width: 400, height: 400);
  // Checkerboard pattern — maximum high-frequency content
  for (int y = 0; y < 400; y++) {
    for (int x = 0; x < 400; x++) {
      final isWhite = ((x ~/ 20) + (y ~/ 20)) % 2 == 0;
      image.setPixelRgb(x, y, isWhite ? 255 : 0, isWhite ? 255 : 0,
          isWhite ? 255 : 0);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Creates a very dark (underexposed) image.
Uint8List _darkJpeg() => _makeJpeg(
    width: 200, height: 200, r: 10, g: 10, b: 10);

/// Creates a very bright (overexposed) image.
Uint8List _brightJpeg() => _makeJpeg(
    width: 200, height: 200, r: 250, g: 250, b: 250);

void main() {
  group('Blur detection', () {
    test('blurry image is detected as blurry', () async {
      final service = MlAnalysisService();
      final issues = await service.analyzeImage(_blurryJpeg());
      expect(issues, contains(QualityIssue.blurry),
          reason: 'Heavily blurred image should be flagged');
    });

    test('sharp checkerboard is NOT detected as blurry', () async {
      final service = MlAnalysisService();
      final issues = await service.analyzeImage(_sharpJpeg());
      expect(issues, isNot(contains(QualityIssue.blurry)),
          reason: 'Checkerboard has maximum sharpness');
    });

    test('empty bytes returns empty issues', () async {
      final service = MlAnalysisService();
      final issues = await service.analyzeImage(Uint8List(0));
      expect(issues, isEmpty);
    });
  });

  group('Low-light detection', () {
    test('very dark image flagged as low light', () async {
      final service = MlAnalysisService();
      final issues = await service.analyzeImage(_darkJpeg());
      expect(issues, contains(QualityIssue.lowLight));
    });

    test('very bright image flagged as low light (overexposed)', () async {
      final service = MlAnalysisService();
      final issues = await service.analyzeImage(_brightJpeg());
      expect(issues, contains(QualityIssue.lowLight));
    });

    test('normal exposure image NOT flagged', () async {
      final service = MlAnalysisService();
      // Mid-grey — clearly normal exposure
      final issues = await service.analyzeImage(
          _makeJpeg(width: 200, height: 200, r: 128, g: 128, b: 128));
      expect(issues, isNot(contains(QualityIssue.lowLight)));
    });
  });

  group('Junk detection', () {
    test('large photo NOT flagged as junk', () async {
      final service = MlAnalysisService();
      // 1200×900 = 1.08MP > 1MP threshold
      final issues = await service.analyzeImage(
          _makeJpeg(width: 1200, height: 900, r: 200, g: 100, b: 50));
      expect(issues, isNot(contains(QualityIssue.junk)));
    });

    test('small solid-color image flagged as junk', () async {
      final service = MlAnalysisService();
      // 100×100 solid red — very few unique colors, small size
      final issues = await service.analyzeImage(
          _makeJpeg(width: 100, height: 100, r: 255, g: 0, b: 0));
      expect(issues, contains(QualityIssue.junk));
    });
  });

  group('Image classification', () {
    test('filename "screenshot_001.jpg" → screenshots', () async {
      final service = MlAnalysisService();
      final bytes = _makeJpeg(width: 100, height: 100, r: 240, g: 240, b: 240);
      final cat = await service.classifyImage(bytes, 'screenshot_001.jpg');
      expect(cat, PhotoCategory.screenshots);
    });

    test('filename "scan_receipt.jpg" → documents', () async {
      final service = MlAnalysisService();
      final bytes = _makeJpeg(width: 100, height: 100, r: 200, g: 200, b: 200);
      final cat = await service.classifyImage(bytes, 'scan_receipt.jpg');
      expect(cat, PhotoCategory.documents);
    });

    test('green-dominant image → nature', () async {
      final service = MlAnalysisService();
      // Strong green dominance
      final bytes = _makeJpeg(width: 100, height: 100, r: 50, g: 150, b: 60);
      final cat = await service.classifyImage(bytes, 'IMG_1234.jpg');
      expect(cat, PhotoCategory.nature);
    });

    test('blue-dominant image → nature', () async {
      final service = MlAnalysisService();
      final bytes = _makeJpeg(width: 100, height: 100, r: 30, g: 80, b: 200);
      final cat = await service.classifyImage(bytes, 'IMG_5678.jpg');
      expect(cat, PhotoCategory.nature);
    });

    test('warm-toned image → food', () async {
      final service = MlAnalysisService();
      // Warm orange — typical food photo
      final bytes = _makeJpeg(width: 100, height: 100, r: 200, g: 130, b: 60);
      final cat = await service.classifyImage(bytes, 'IMG_food.jpg');
      expect(cat, PhotoCategory.food);
    });

    test('skin-tone image → people', () async {
      final service = MlAnalysisService();
      // r=170, g=140, b=125: R-B=45 < 50 (not food), R>G+10 ✓, G>B+5 ✓
      final bytes = _makeJpeg(width: 100, height: 100, r: 170, g: 140, b: 125);
      final cat = await service.classifyImage(bytes, 'IMG_portrait.jpg');
      expect(cat, PhotoCategory.people);
    });

    test('invalid bytes → other', () async {
      final service = MlAnalysisService();
      final cat = await service.classifyImage(Uint8List(0), 'unknown.jpg');
      expect(cat, PhotoCategory.other);
    });
  });

  group('Smart filename generation', () {
    test('generates correct format without location', () async {
      final service = MlAnalysisService();
      final name = await service.suggestFilename(
        originalName: 'IMG_1234.jpg',
        category: PhotoCategory.food,
        createdAt: DateTime(2024, 3, 15),
      );
      expect(name, 'Food_2024-03-15.jpg');
    });

    test('generates correct format with location', () async {
      final service = MlAnalysisService();
      final name = await service.suggestFilename(
        originalName: 'IMG_1234.jpg',
        category: PhotoCategory.nature,
        createdAt: DateTime(2024, 6, 1),
        location: 'Sunset Beach Goa',
      );
      expect(name, 'Nature_Sunset_Beach_Goa_2024-06-01.jpg');
    });

    test('preserves original extension', () async {
      final service = MlAnalysisService();
      final name = await service.suggestFilename(
        originalName: 'photo.png',
        category: PhotoCategory.people,
        createdAt: DateTime(2024, 1, 5),
      );
      expect(name, endsWith('.png'));
    });

    test('sanitizes special characters in location', () async {
      final service = MlAnalysisService();
      final name = await service.suggestFilename(
        originalName: 'img.jpg',
        category: PhotoCategory.other,
        createdAt: DateTime(2024, 1, 1),
        location: 'New York, USA!',
      );
      // Special chars stripped, spaces → underscores
      expect(name, isNot(contains(',')));
      expect(name, isNot(contains('!')));
    });

    test('handles missing extension gracefully', () async {
      final service = MlAnalysisService();
      final name = await service.suggestFilename(
        originalName: 'noextension',
        category: PhotoCategory.other,
        createdAt: DateTime(2024, 1, 1),
      );
      expect(name, endsWith('.jpg'));
    });

    test('pads single-digit month and day', () async {
      final service = MlAnalysisService();
      final name = await service.suggestFilename(
        originalName: 'x.jpg',
        category: PhotoCategory.other,
        createdAt: DateTime(2024, 1, 5),
      );
      expect(name, contains('2024-01-05'));
    });
  });
}
