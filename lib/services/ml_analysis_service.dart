import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/models.dart';

/// Runs image quality analysis in a separate Dart isolate to keep UI responsive.
class MlAnalysisService {
  // Laplacian variance: empirically calibrated thresholds.
  // Sharp photos typically score >500; blurry <150.
  // Using 200 as conservative threshold to reduce false positives.
  static const double _blurThreshold = 200.0;

  // Luminance range for "normal" exposure (0–255 scale).
  static const double _brightnessMin = 20.0;
  static const double _brightnessMax = 235.0;

  // Junk: require very few unique quantized colors AND small image dimensions
  static const int _junkColorThreshold = 8;

  Future<List<QualityIssue>> analyzeImage(Uint8List bytes) async {
    return Isolate.run(() => _analyzeImage(bytes));
  }

  Future<PhotoCategory> classifyImage(Uint8List bytes, String filename) async {
    return Isolate.run(() => _classifyImage(bytes, filename));
  }

  Future<String> suggestFilename({
    required String originalName,
    required PhotoCategory category,
    required DateTime createdAt,
    String? location,
  }) async {
    return _buildSmartName(
      originalName: originalName,
      category: category,
      createdAt: createdAt,
      location: location,
    );
  }

  // ── Public static methods for batch processing (no isolate overhead) ────

  static bool isBlurryStatic(img.Image image) => _isBlurry(image);
  static bool isLowLightStatic(img.Image image) => _isLowLight(image);
  static bool looksLikeJunkStatic(img.Image image) => _looksLikeJunk(image);

  /// Multi-signal classification using filename patterns, EXIF-derived hints,
  /// aspect ratio, color histogram, texture, and edge density.
  ///
  /// Scoring system: each signal adds weighted votes to categories.
  /// The category with the highest score wins. This avoids the old approach
  /// of simple if/else on average RGB which caused massive misclassification.
  static PhotoCategory classifyFromImage(img.Image image, String filename) {
    final scores = <PhotoCategory, double>{
      PhotoCategory.screenshots: 0,
      PhotoCategory.documents: 0,
      PhotoCategory.food: 0,
      PhotoCategory.people: 0,
      PhotoCategory.nature: 0,
      PhotoCategory.other: 0,
    };

    // ── Signal 1: Filename patterns (weight: 10 — very reliable) ──────────
    _scoreFilename(filename.toLowerCase(), scores);

    // ── Signal 2: Aspect ratio + dimensions (weight: 3) ───────────────────
    _scoreAspectRatio(image, scores);

    // ── Signal 3: Color histogram analysis (weight: 2) ────────────────────
    final small = img.copyResize(image, width: 64, height: 64);
    final colorStats = _computeColorStats(small);
    _scoreColorHistogram(colorStats, scores);

    // ── Signal 4: Edge density — text/UI vs natural (weight: 2) ───────────
    _scoreEdgeDensity(small, scores);

    // ── Signal 5: Color diversity — natural scenes vs UI (weight: 1.5) ────
    _scoreColorDiversity(small, scores);

    // ── Signal 6: Skin tone pixel ratio (weight: 3) ───────────────────────
    _scoreSkinTones(small, colorStats, scores);

    // ── Signal 7: Green/blue region ratio for nature (weight: 2) ──────────
    _scoreNatureRegions(small, scores);

    // Pick highest score; default to 'other' on ties
    var best = PhotoCategory.other;
    var bestScore = 0.0;
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        best = entry.key;
      }
    }

    // Require minimum confidence to avoid weak classifications
    if (bestScore < 3.0) return PhotoCategory.other;

    return best;
  }

  /// Public static smart name builder for batch processing.
  static String buildSmartNameStatic({
    required String originalName,
    required PhotoCategory category,
    required DateTime createdAt,
    String? location,
  }) {
    return _buildSmartName(
      originalName: originalName,
      category: category,
      createdAt: createdAt,
      location: location,
    );
  }

  // ── Classification signals ──────────────────────────────────────────────

  static void _scoreFilename(String lower, Map<PhotoCategory, double> scores) {
    // Screenshots
    if (lower.contains('screenshot') ||
        lower.startsWith('screen_') ||
        lower.startsWith('screen-') ||
        lower.contains('screen shot') ||
        lower.contains('capture') && lower.contains('screen')) {
      scores[PhotoCategory.screenshots] = scores[PhotoCategory.screenshots]! + 10;
    }

    // Documents
    if (lower.contains('document') ||
        lower.contains('scan') && !lower.contains('screenshot') ||
        lower.contains('receipt') ||
        lower.contains('invoice') ||
        lower.contains('contract') ||
        lower.contains('certificate') ||
        lower.contains('pdf') ||
        lower.contains('bill')) {
      scores[PhotoCategory.documents] = scores[PhotoCategory.documents]! + 10;
    }

    // Food hints
    if (lower.contains('food') ||
        lower.contains('meal') ||
        lower.contains('dish') ||
        lower.contains('recipe') ||
        lower.contains('restaurant') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakfast')) {
      scores[PhotoCategory.food] = scores[PhotoCategory.food]! + 8;
    }

    // People hints
    if (lower.contains('selfie') ||
        lower.contains('portrait') ||
        lower.contains('group') ||
        lower.contains('family') ||
        lower.contains('wedding') ||
        lower.contains('birthday') ||
        lower.contains('party')) {
      scores[PhotoCategory.people] = scores[PhotoCategory.people]! + 8;
    }

    // Nature hints
    if (lower.contains('landscape') ||
        lower.contains('sunset') ||
        lower.contains('sunrise') ||
        lower.contains('mountain') ||
        lower.contains('beach') ||
        lower.contains('forest') ||
        lower.contains('garden') ||
        lower.contains('flower') ||
        lower.contains('nature') ||
        lower.contains('lake') ||
        lower.contains('ocean') ||
        lower.contains('sky') ||
        lower.contains('park')) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 8;
    }

    // WhatsApp forwarded images → other
    if (RegExp(r'img-\d{8}-wa\d+').hasMatch(lower)) {
      scores[PhotoCategory.other] = scores[PhotoCategory.other]! + 5;
    }

    // Camera default names (IMG_, DSC_, DCIM) → slight people/nature boost
    if (RegExp(r'^(img_|dsc_|dcim|photo_)\d+').hasMatch(lower)) {
      scores[PhotoCategory.people] = scores[PhotoCategory.people]! + 1;
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 1;
    }
  }

  static void _scoreAspectRatio(img.Image image, Map<PhotoCategory, double> scores) {
    final w = image.width;
    final h = image.height;
    final ratio = w / h;

    // Phone screenshots are typically exact screen ratios
    // Common: 9:16 (0.5625), 9:19.5 (0.4615), 9:20 (0.45)
    if (ratio > 0.44 && ratio < 0.58 && w >= 720) {
      scores[PhotoCategory.screenshots] = scores[PhotoCategory.screenshots]! + 3;
    }
    // Landscape screenshots (16:9)
    if (ratio > 1.7 && ratio < 1.85 && h >= 720) {
      scores[PhotoCategory.screenshots] = scores[PhotoCategory.screenshots]! + 2;
    }

    // Square-ish photos (Instagram-style) → food or people
    if (ratio > 0.9 && ratio < 1.1) {
      scores[PhotoCategory.food] = scores[PhotoCategory.food]! + 1;
      scores[PhotoCategory.people] = scores[PhotoCategory.people]! + 1;
    }

    // Very wide panoramas → nature
    if (ratio > 2.5) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 3;
    }

    // Document scans are often A4 ratio (~0.707 or ~1.414)
    if ((ratio > 0.68 && ratio < 0.73) || (ratio > 1.38 && ratio < 1.45)) {
      scores[PhotoCategory.documents] = scores[PhotoCategory.documents]! + 2;
    }
  }

  static _ColorStats _computeColorStats(img.Image small) {
    double rSum = 0, gSum = 0, bSum = 0;
    double rSumSq = 0, gSumSq = 0, bSumSq = 0;
    double hueSum = 0, satSum = 0;
    final count = small.width * small.height;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        rSum += r; gSum += g; bSum += b;
        rSumSq += r * r; gSumSq += g * g; bSumSq += b * b;

        // HSV for saturation analysis
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final delta = maxC - minC;
        if (maxC > 0) satSum += delta / maxC;
        if (delta > 0) {
          double hue;
          if (maxC == r) {
            hue = 60 * (((g - b) / delta) % 6);
          } else if (maxC == g) {
            hue = 60 * (((b - r) / delta) + 2);
          } else {
            hue = 60 * (((r - g) / delta) + 4);
          }
          if (hue < 0) hue += 360;
          hueSum += hue;
        }
      }
    }

    return _ColorStats(
      avgR: rSum / count,
      avgG: gSum / count,
      avgB: bSum / count,
      varR: (rSumSq / count) - (rSum / count) * (rSum / count),
      varG: (gSumSq / count) - (gSum / count) * (gSum / count),
      varB: (bSumSq / count) - (bSum / count) * (bSum / count),
      avgSat: satSum / count,
      avgHue: hueSum / count,
      count: count,
    );
  }

  static void _scoreColorHistogram(_ColorStats s, Map<PhotoCategory, double> scores) {
    final totalVar = s.varR + s.varG + s.varB;

    // Screenshots: very low variance + bright (UI backgrounds)
    if (totalVar < 1500 && s.avgR > 180 && s.avgG > 180 && s.avgB > 180) {
      scores[PhotoCategory.screenshots] = scores[PhotoCategory.screenshots]! + 2;
    }

    // Documents: very low saturation + high brightness (white paper)
    if (s.avgSat < 0.1 && (s.avgR + s.avgG + s.avgB) / 3 > 200) {
      scores[PhotoCategory.documents] = scores[PhotoCategory.documents]! + 2;
    }

    // Food: warm tones with moderate-high saturation
    // Warm hue range: 0-60 (red-orange-yellow)
    if (s.avgHue < 60 && s.avgSat > 0.25 &&
        s.avgR > 140 && s.avgR > s.avgB + 30) {
      scores[PhotoCategory.food] = scores[PhotoCategory.food]! + 2;
    }

    // Nature: high saturation + high color variance (diverse colors)
    if (s.avgSat > 0.3 && totalVar > 3000) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 1.5;
    }
  }

  static void _scoreEdgeDensity(img.Image small, Map<PhotoCategory, double> scores) {
    final gray = img.grayscale(img.copyResize(small, width: 32, height: 32));
    int edgeCount = 0;
    int totalPixels = 0;

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final c = img.getLuminance(gray.getPixel(x, y));
        final r = img.getLuminance(gray.getPixel(x + 1, y));
        final b = img.getLuminance(gray.getPixel(x, y + 1));
        if ((c - r).abs() > 50 || (c - b).abs() > 50) edgeCount++;
        totalPixels++;
      }
    }

    final edgeRatio = totalPixels > 0 ? edgeCount / totalPixels : 0.0;

    // High edge density → text/UI (screenshots, documents)
    if (edgeRatio > 0.35) {
      scores[PhotoCategory.screenshots] = scores[PhotoCategory.screenshots]! + 1.5;
      scores[PhotoCategory.documents] = scores[PhotoCategory.documents]! + 1.5;
    }

    // Low edge density → smooth gradients (sky, water, food close-ups)
    if (edgeRatio < 0.15) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 1;
      scores[PhotoCategory.food] = scores[PhotoCategory.food]! + 0.5;
    }
  }

  static void _scoreColorDiversity(img.Image small, Map<PhotoCategory, double> scores) {
    final quantized = img.copyResize(small, width: 32, height: 32);
    final colors = <int>{};
    for (int y = 0; y < quantized.height; y++) {
      for (int x = 0; x < quantized.width; x++) {
        final p = quantized.getPixel(x, y);
        // Quantize to 16 levels per channel (4-bit)
        final r = (p.r.toInt() >> 4) << 4;
        final g = (p.g.toInt() >> 4) << 4;
        final b = (p.b.toInt() >> 4) << 4;
        colors.add((r << 16) | (g << 8) | b);
      }
    }

    // Very few colors → screenshot/document (flat UI, white paper)
    if (colors.length < 30) {
      scores[PhotoCategory.screenshots] = scores[PhotoCategory.screenshots]! + 1.5;
      scores[PhotoCategory.documents] = scores[PhotoCategory.documents]! + 1;
    }

    // Many colors → natural scene
    if (colors.length > 200) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 1.5;
      scores[PhotoCategory.people] = scores[PhotoCategory.people]! + 0.5;
    }
  }

  static void _scoreSkinTones(img.Image small, _ColorStats stats,
      Map<PhotoCategory, double> scores) {
    int skinPixels = 0;
    final total = small.width * small.height;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();

        // Skin tone detection using multiple color space rules:
        // 1. RGB rule: R > 95, G > 40, B > 20, R > G, R > B, |R-G| > 15
        // 2. Normalized: r/g ratio in skin range
        // Based on Peer et al. skin detection research
        if (r > 95 && g > 40 && b > 20 &&
            r > g && r > b &&
            (r - g).abs() > 15 &&
            r - b > 15) {
          // Additional check: not too saturated (avoids red objects)
          final maxC = math.max(r, math.max(g, b));
          final minC = math.min(r, math.min(g, b));
          final sat = maxC > 0 ? (maxC - minC) / maxC : 0;
          if (sat < 0.68) {
            skinPixels++;
          }
        }
      }
    }

    final skinRatio = skinPixels / total;

    // >15% skin pixels → likely has people
    if (skinRatio > 0.15) {
      scores[PhotoCategory.people] = scores[PhotoCategory.people]! + 3;
    }
    // >30% → very likely portrait/selfie
    if (skinRatio > 0.30) {
      scores[PhotoCategory.people] = scores[PhotoCategory.people]! + 2;
    }
  }

  static void _scoreNatureRegions(img.Image small, Map<PhotoCategory, double> scores) {
    int greenPixels = 0;
    int bluePixels = 0;
    int brownPixels = 0;
    final total = small.width * small.height;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();

        // Green vegetation: G dominant, not too bright (avoids lime UI colors)
        if (g > r + 10 && g > b + 10 && g > 50 && g < 220) {
          greenPixels++;
        }
        // Sky blue: B dominant, moderate brightness
        if (b > r + 15 && b > g + 5 && b > 100 && r < 180) {
          bluePixels++;
        }
        // Earth/sand/wood tones (avoids skin by requiring lower saturation)
        if (r > g && g > b && r - b > 30 && r < 180 && g < 140) {
          brownPixels++;
        }
      }
    }

    final greenRatio = greenPixels / total;
    final blueRatio = bluePixels / total;
    final natureRatio = greenRatio + blueRatio;

    // >25% green+blue pixels → nature scene
    if (natureRatio > 0.25) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 2;
    }
    if (natureRatio > 0.45) {
      scores[PhotoCategory.nature] = scores[PhotoCategory.nature]! + 2;
    }

    // Brown/earth tones without green → food (wooden table, bread, etc.)
    final brownRatio = brownPixels / total;
    if (brownRatio > 0.2 && greenRatio < 0.1) {
      scores[PhotoCategory.food] = scores[PhotoCategory.food]! + 1;
    }
  }

  // ── Quality analysis ────────────────────────────────────────────────────

  static List<QualityIssue> _analyzeImage(Uint8List bytes) {
    final issues = <QualityIssue>[];
    if (bytes.isEmpty) return issues;
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return issues;
    }
    if (image == null) return issues;

    if (_isBlurry(image)) issues.add(QualityIssue.blurry);
    if (_isLowLight(image)) issues.add(QualityIssue.lowLight);
    if (_looksLikeJunk(image)) issues.add(QualityIssue.junk);

    return issues;
  }

  static bool _isBlurry(img.Image image) {
    final size = math.min(math.min(image.width, image.height), 512);
    final cx = (image.width - size) ~/ 2;
    final cy = (image.height - size) ~/ 2;
    final cropped = img.copyCrop(image, x: cx, y: cy, width: size, height: size);
    final gray = img.grayscale(cropped);

    double sumSq = 0;
    double sum = 0;
    int count = 0;

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final c = img.getLuminance(gray.getPixel(x, y));
        final t = img.getLuminance(gray.getPixel(x, y - 1));
        final b = img.getLuminance(gray.getPixel(x, y + 1));
        final l = img.getLuminance(gray.getPixel(x - 1, y));
        final r = img.getLuminance(gray.getPixel(x + 1, y));
        final lap = (4 * c - t - b - l - r).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return false;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance < _blurThreshold;
  }

  static bool _isLowLight(img.Image image) {
    final small = img.copyResize(image, width: 128, height: 128);
    double total = 0;
    int count = 0;
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        total += img.getLuminance(small.getPixel(x, y));
        count++;
      }
    }
    if (count == 0) return false;
    final avg = total / count;
    return avg < _brightnessMin || avg > _brightnessMax;
  }

  static bool _looksLikeJunk(img.Image image) {
    if (image.width * image.height > 1000000) return false;

    final small = img.copyResize(image, width: 32, height: 32);
    final colors = <int>{};
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        final r = (p.r.toInt() ~/ 32) * 32;
        final g = (p.g.toInt() ~/ 32) * 32;
        final bv = (p.b.toInt() ~/ 32) * 32;
        colors.add((r << 16) | (g << 8) | bv);
      }
    }
    return colors.length < _junkColorThreshold;
  }

  static PhotoCategory _classifyImage(Uint8List bytes, String filename) {
    if (bytes.isEmpty) return PhotoCategory.other;
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return PhotoCategory.other;
    }
    if (image == null) return PhotoCategory.other;
    return classifyFromImage(image, filename);
  }

  static String _buildSmartName({
    required String originalName,
    required PhotoCategory category,
    required DateTime createdAt,
    String? location,
  }) {
    final prefix = switch (category) {
      PhotoCategory.food => 'Food',
      PhotoCategory.people => 'People',
      PhotoCategory.nature => 'Nature',
      PhotoCategory.screenshots => 'Screenshot',
      PhotoCategory.documents => 'Document',
      PhotoCategory.other => 'Photo',
    };

    final date =
        '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-'
        '${createdAt.day.toString().padLeft(2, '0')}';

    final dotIdx = originalName.lastIndexOf('.');
    final ext = dotIdx >= 0 && dotIdx < originalName.length - 1
        ? originalName.substring(dotIdx).toLowerCase()
        : '.jpg';

    if (location != null && location.trim().isNotEmpty) {
      final loc = location
          .trim()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      return '${prefix}_${loc}_$date$ext';
    }
    return '${prefix}_$date$ext';
  }
}

class _ColorStats {
  final double avgR, avgG, avgB;
  final double varR, varG, varB;
  final double avgSat, avgHue;
  final int count;

  const _ColorStats({
    required this.avgR, required this.avgG, required this.avgB,
    required this.varR, required this.varG, required this.varB,
    required this.avgSat, required this.avgHue,
    required this.count,
  });
}
