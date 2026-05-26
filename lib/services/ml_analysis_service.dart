import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Blur detection via Laplacian variance.
///
/// Sharp photos typically score >500; blurry <150.
/// Threshold of 200 is conservative to reduce false positives.
class MlAnalysisService {
  static const double _blurThreshold = 200.0;

  static bool isBlurryStatic(img.Image image) => _isBlurry(image);

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
}
