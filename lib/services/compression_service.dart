import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class CompressionService {
  /// Compresses a single file. Returns null if the file cannot be decoded
  /// (e.g. unsupported format, corrupted file) rather than throwing.
  Future<CompressionResult?> compress(
    String sourcePath,
    CompressionMode mode,
  ) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final bytes = await sourceFile.readAsBytes();
    if (bytes.isEmpty) return null;

    final originalSize = bytes.length;

    Uint8List? compressedBytes;
    try {
      compressedBytes = await Isolate.run(() => _compress(bytes, mode));
    } catch (_) {
      return null;
    }

    if (compressedBytes == null) return null;

    // Only save if we actually reduced size — never inflate a file
    if (compressedBytes.length >= originalSize) {
      compressedBytes = bytes; // keep original
    }

    final dir = await getTemporaryDirectory();
    final baseName = p.basenameWithoutExtension(sourcePath);
    // Always output as JPEG for smart/aggressive; preserve format for lossless
    final outExt = mode == CompressionMode.lossless
        ? p.extension(sourcePath).toLowerCase().replaceAll('.heic', '.jpg')
        : '.jpg';
    final outName = '${baseName}_compressed$outExt';
    final outPath = p.join(dir.path, outName);

    await File(outPath).writeAsBytes(compressedBytes);

    return CompressionResult(
      originalPath: sourcePath,
      compressedPath: outPath,
      originalBytes: originalSize,
      compressedBytes: compressedBytes.length,
      mode: mode,
    );
  }

  Future<List<CompressionResult>> compressBatch(
    List<String> paths,
    CompressionMode mode, {
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <CompressionResult>[];
    for (int i = 0; i < paths.length; i++) {
      final result = await compress(paths[i], mode);
      if (result != null) results.add(result);
      onProgress?.call(i + 1, paths.length);
    }
    return results;
  }

  static Uint8List? _compress(Uint8List bytes, CompressionMode mode) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;

    // Strip EXIF orientation and apply it to pixel data so the image
    // displays correctly after compression
    image = img.bakeOrientation(image);

    switch (mode) {
      case CompressionMode.lossless:
        // Re-encode as PNG with level 6 (good compression, reasonable speed).
        // Strips metadata. For JPEG inputs this will increase size — caller
        // handles the "never inflate" guard.
        try {
          return Uint8List.fromList(img.encodePng(image, level: 6));
        } catch (_) {
          return null;
        }

      case CompressionMode.smart:
        // JPEG at 82% quality — visually lossless for most photos,
        // typically 40–60% size reduction vs original camera JPEG.
        try {
          return Uint8List.fromList(img.encodeJpg(image, quality: 82));
        } catch (_) {
          return null;
        }

      case CompressionMode.aggressive:
        // Resize to max 1920px on longest edge (preserving aspect ratio),
        // then JPEG at 60% quality. Targets up to 90% reduction.
        try {
          img.Image target = image;
          const maxDim = 1920;
          if (image.width > maxDim || image.height > maxDim) {
            if (image.width >= image.height) {
              // Landscape: constrain width
              target = img.copyResize(image,
                  width: maxDim,
                  interpolation: img.Interpolation.linear);
            } else {
              // Portrait: constrain height
              target = img.copyResize(image,
                  height: maxDim,
                  interpolation: img.Interpolation.linear);
            }
          }
          return Uint8List.fromList(img.encodeJpg(target, quality: 60));
        } catch (_) {
          return null;
        }
    }
  }
}
