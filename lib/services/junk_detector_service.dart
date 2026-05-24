import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/models.dart';

/// Identifies memes, WhatsApp forwards, and low-value images.
class JunkDetectorService {
  static const List<String> _junkPatterns = [
    'whatsapp',
    'forward',
    'meme',
    'funny',
    'viral',
    'share',
    'received',
  ];

  static const List<String> _junkDimensions = [
    '1280x720',
    '1920x1080',
    '720x1280',
  ];

  bool isJunkByFilename(String filename) {
    return isJunkByFilenameStatic(filename);
  }

  /// Static variant for batch processing in isolates.
  static bool isJunkByFilenameStatic(String filename) {
    final lower = filename.toLowerCase();
    return _junkPatterns.any((p) => lower.contains(p));
  }

  bool isJunkByDimensions(int width, int height) {
    final dim = '${width}x$height';
    return _junkDimensions.contains(dim);
  }

  /// Detects images with heavy text overlay (memes/forwards).
  bool hasHeavyTextOverlay(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return false;

    final small = img.copyResize(image, width: 64, height: 64);
    final gray = img.grayscale(small);

    // Count high-contrast edge pixels — text creates many sharp edges
    int edgeCount = 0;
    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final center = img.getLuminance(gray.getPixel(x, y));
        final right = img.getLuminance(gray.getPixel(x + 1, y));
        final bottom = img.getLuminance(gray.getPixel(x, y + 1));
        if ((center - right).abs() > 80 || (center - bottom).abs() > 80) {
          edgeCount++;
        }
      }
    }

    final edgeRatio = edgeCount / (gray.width * gray.height);
    return edgeRatio > 0.25; // >25% edge pixels → likely text-heavy
  }

  List<QualityIssue> detectJunkIssues(
      Uint8List bytes, String filename) {
    final issues = <QualityIssue>[];
    if (isJunkByFilename(filename) || hasHeavyTextOverlay(bytes)) {
      issues.add(QualityIssue.junk);
    }
    return issues;
  }
}
