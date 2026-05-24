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
  // Below 20 = near-black (underexposed); above 235 = near-white (overexposed).
  static const double _brightnessMin = 20.0;
  static const double _brightnessMax = 235.0;

  // Junk: require very few unique quantized colors AND small image dimensions
  // to avoid flagging legitimate night shots or minimalist photos.
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
  // These accept a pre-decoded image so the scanner can decode once and
  // share the result across all analyses.

  static bool isBlurryStatic(img.Image image) => _isBlurry(image);
  static bool isLowLightStatic(img.Image image) => _isLowLight(image);
  static bool looksLikeJunkStatic(img.Image image) => _looksLikeJunk(image);

  /// Classify from a pre-decoded image. Falls back to filename heuristics
  /// first (same as _classifyImage) but skips the decode step.
  static PhotoCategory classifyFromImage(img.Image image, String filename) {
    final lower = filename.toLowerCase();

    // Filename fast-path
    if (lower.contains('screenshot') ||
        lower.startsWith('screen_') ||
        lower.startsWith('screen-')) {
      return PhotoCategory.screenshots;
    }
    if (lower.contains('document') ||
        lower.contains('scan') ||
        lower.contains('receipt') ||
        lower.contains('invoice') ||
        lower.contains('contract')) {
      return PhotoCategory.documents;
    }
    if (RegExp(r'img-\d{8}-wa\d+').hasMatch(lower)) {
      return PhotoCategory.other;
    }

    // Color analysis on pre-decoded image
    final small = img.copyResize(image, width: 64, height: 64);
    double rSum = 0, gSum = 0, bSum = 0;
    double rSumSq = 0, gSumSq = 0, bSumSq = 0;
    final count = small.width * small.height;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        rSum += p.r; gSum += p.g; bSum += p.b;
        rSumSq += p.r * p.r;
        gSumSq += p.g * p.g;
        bSumSq += p.b * p.b;
      }
    }

    final avgR = rSum / count;
    final avgG = gSum / count;
    final avgB = bSum / count;
    final varR = (rSumSq / count) - (avgR * avgR);
    final varG = (gSumSq / count) - (avgG * avgG);
    final varB = (bSumSq / count) - (avgB * avgB);
    final totalVar = varR + varG + varB;

    if (totalVar < 1500 && avgR > 180 && avgG > 180 && avgB > 180) {
      return PhotoCategory.screenshots;
    }
    if (avgG > avgR + 15 && avgG > avgB + 5) {
      return PhotoCategory.nature;
    }
    if (avgB > avgR + 20 && avgB > avgG + 10) {
      return PhotoCategory.nature;
    }
    if (avgR > avgB + 50 && avgR > 130 && avgG > 90 && avgB < 120) {
      return PhotoCategory.food;
    }
    if (avgR > avgG + 10 &&
        avgG > avgB + 5 &&
        avgR > 140 && avgR < 240 &&
        avgG > 90 && avgG < 190 &&
        avgB > 70 && avgB < 160) {
      return PhotoCategory.people;
    }

    return PhotoCategory.other;
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

  // ── Isolate-safe helpers ──────────────────────────────────────────────────

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

  /// Laplacian variance blur detection.
  ///
  /// Works on a 512×512 crop of the center of the image — large enough to
  /// preserve sharpness signal, small enough to be fast. Resizing to 256 (old
  /// approach) destroyed high-frequency detail and caused false positives on
  /// legitimately sharp photos.
  static bool _isBlurry(img.Image image) {
    // Use center crop at 512px to preserve sharpness signal
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
        // Standard 5-point Laplacian kernel
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

  /// Average luminance check for under/over-exposed images.
  static bool _isLowLight(img.Image image) {
    // Sample every 4th pixel for speed on large images
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

  /// Junk detection: memes/forwards typically have very few distinct colors
  /// AND are small (forwarded images are often compressed to low resolution).
  /// Requiring BOTH conditions avoids flagging night shots and minimalist art.
  static bool _looksLikeJunk(img.Image image) {
    // Only flag as junk if image is small (forwarded/meme dimensions)
    // Large photos (>1MP) are almost never memes
    if (image.width * image.height > 1000000) return false;

    final small = img.copyResize(image, width: 32, height: 32);
    final colors = <int>{};
    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        // Quantize to 8 levels per channel (3-bit)
        final r = (p.r ~/ 32) * 32;
        final g = (p.g ~/ 32) * 32;
        final bv = (p.b ~/ 32) * 32;
        colors.add((r << 16) | (g << 8) | bv);
      }
    }
    return colors.length < _junkColorThreshold;
  }

  /// Image classification using filename heuristics + color channel analysis.
  ///
  /// Decodes image only once. Filename fast-path avoids decode entirely for
  /// screenshots and documents.
  static PhotoCategory _classifyImage(Uint8List bytes, String filename) {
    final lower = filename.toLowerCase();

    // ── Filename fast-path (no decode needed) ─────────────────────────────
    if (lower.contains('screenshot') ||
        lower.startsWith('screen_') ||
        lower.startsWith('screen-')) {
      return PhotoCategory.screenshots;
    }
    if (lower.contains('document') ||
        lower.contains('scan') ||
        lower.contains('receipt') ||
        lower.contains('invoice') ||
        lower.contains('contract')) {
      return PhotoCategory.documents;
    }
    // WhatsApp images: IMG-YYYYMMDD-WA####.jpg
    if (RegExp(r'img-\d{8}-wa\d+').hasMatch(lower)) {
      return PhotoCategory.other;
    }

    // ── Color analysis ────────────────────────────────────────────────────
    if (bytes.isEmpty) return PhotoCategory.other;
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return PhotoCategory.other;
    }
    if (image == null) return PhotoCategory.other;

    // Downsample to 64×64 for fast color stats
    final small = img.copyResize(image, width: 64, height: 64);
    double rSum = 0, gSum = 0, bSum = 0;
    double rSumSq = 0, gSumSq = 0, bSumSq = 0;
    final count = small.width * small.height;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        rSum += p.r; gSum += p.g; bSum += p.b;
        rSumSq += p.r * p.r;
        gSumSq += p.g * p.g;
        bSumSq += p.b * p.b;
      }
    }

    final avgR = rSum / count;
    final avgG = gSum / count;
    final avgB = bSum / count;

    // Color variance — high variance = colorful/complex scene
    final varR = (rSumSq / count) - (avgR * avgR);
    final varG = (gSumSq / count) - (avgG * avgG);
    final varB = (bSumSq / count) - (avgB * avgB);
    final totalVar = varR + varG + varB;

    // Screenshots: low color variance (mostly UI colors) + not too dark
    if (totalVar < 1500 && avgR > 180 && avgG > 180 && avgB > 180) {
      return PhotoCategory.screenshots;
    }

    // Nature: dominant green (foliage) or blue (sky/water)
    // Require meaningful dominance margin to avoid false positives
    if (avgG > avgR + 15 && avgG > avgB + 5) {
      return PhotoCategory.nature; // green dominant → foliage/landscape
    }
    if (avgB > avgR + 20 && avgB > avgG + 10) {
      return PhotoCategory.nature; // blue dominant → sky/water
    }

    // Food: warm tones — red/orange dominant, low blue
    // Typical food photos: avgR 160–220, avgG 120–170, avgB 60–110
    if (avgR > avgB + 50 && avgR > 130 && avgG > 90 && avgB < 120) {
      return PhotoCategory.food;
    }

    // People: skin tone range
    // Skin: R > G > B, R in 150–230, G in 100–180, B in 80–150
    // Require R-B spread to distinguish from generic warm photos
    if (avgR > avgG + 10 &&
        avgG > avgB + 5 &&
        avgR > 140 && avgR < 240 &&
        avgG > 90 && avgG < 190 &&
        avgB > 70 && avgB < 160) {
      return PhotoCategory.people;
    }

    return PhotoCategory.other;
  }

  /// Generates a smart filename: Category_Location_YYYY-MM-DD.ext
  /// Sanitizes location string and preserves original extension.
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

    // Preserve original extension; default to .jpg
    final dotIdx = originalName.lastIndexOf('.');
    final ext = dotIdx >= 0 && dotIdx < originalName.length - 1
        ? originalName.substring(dotIdx).toLowerCase()
        : '.jpg';

    if (location != null && location.trim().isNotEmpty) {
      // Sanitize: replace spaces/special chars with underscore
      final loc = location
          .trim()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      return '${prefix}_${loc}_$date$ext';
    }
    return '${prefix}_$date$ext';
  }
}
