import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/services/compression_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Mock path_provider so getTemporaryDirectory() works in tests
class _MockPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;
}

Uint8List _testJpeg({int width = 800, int height = 600, int quality = 95}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 255 ~/ width), (y * 255 ~/ height),
          ((x + y) * 128 ~/ (width + height)));
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

File _writeTempFile(Uint8List bytes, String name) {
  final file = File('${Directory.systemTemp.path}/$name');
  file.writeAsBytesSync(bytes);
  return file;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _MockPathProvider();
  });

  group('CompressionService', () {
    late CompressionService service;
    setUp(() => service = CompressionService());

    test('smart mode reduces file size', () async {
      final bytes = _testJpeg(quality: 100);
      final file = _writeTempFile(bytes, 'test_smart.jpg');
      addTearDown(file.deleteSync);

      final result = await service.compress(file.path, CompressionMode.smart);
      expect(result, isNotNull);
      expect(result!.compressedBytes, lessThan(result.originalBytes));
      expect(result.savedPercent, greaterThan(0));
      addTearDown(() => File(result.compressedPath).deleteSync());
    });

    test('aggressive mode reduces size more than smart', () async {
      final bytes = _testJpeg(width: 2000, height: 1500, quality: 100);
      // Use separate input files so output filenames don't collide
      final fileForSmart = _writeTempFile(bytes, 'test_smart_input.jpg');
      final fileForAggressive =
          _writeTempFile(bytes, 'test_aggressive_input.jpg');
      addTearDown(fileForSmart.deleteSync);
      addTearDown(fileForAggressive.deleteSync);

      final smart =
          await service.compress(fileForSmart.path, CompressionMode.smart);
      final aggressive = await service.compress(
          fileForAggressive.path, CompressionMode.aggressive);

      expect(smart, isNotNull);
      expect(aggressive, isNotNull);
      expect(aggressive!.compressedBytes,
          lessThanOrEqualTo(smart!.compressedBytes));

      addTearDown(() {
        final f = File(smart.compressedPath);
        if (f.existsSync()) f.deleteSync();
      });
      addTearDown(() {
        final f = File(aggressive.compressedPath);
        if (f.existsSync()) f.deleteSync();
      });
    });

    test('aggressive mode resizes large images to max 1920px', () async {
      final bytes = _testJpeg(width: 3000, height: 2000, quality: 95);
      final file = _writeTempFile(bytes, 'test_resize.jpg');
      addTearDown(file.deleteSync);

      final result =
          await service.compress(file.path, CompressionMode.aggressive);
      expect(result, isNotNull);

      final outFile = File(result!.compressedPath);
      addTearDown(outFile.deleteSync);

      final outImage = img.decodeImage(outFile.readAsBytesSync());
      expect(outImage, isNotNull);
      expect(outImage!.width, lessThanOrEqualTo(1920));
      expect(outImage.height, lessThanOrEqualTo(1920));
    });

    test('aggressive mode preserves aspect ratio', () async {
      // 3000×1000 — 3:1 landscape
      final bytes = _testJpeg(width: 3000, height: 1000, quality: 95);
      final file = _writeTempFile(bytes, 'test_aspect.jpg');
      addTearDown(file.deleteSync);

      final result =
          await service.compress(file.path, CompressionMode.aggressive);
      expect(result, isNotNull);

      final outFile = File(result!.compressedPath);
      addTearDown(outFile.deleteSync);

      final outImage = img.decodeImage(outFile.readAsBytesSync());
      expect(outImage, isNotNull);
      final ratio = outImage!.width / outImage.height;
      expect(ratio, closeTo(3.0, 0.15),
          reason: 'Aspect ratio must be preserved (got $ratio)');
    });

    test('never inflates already-compressed file', () async {
      final bytes = _testJpeg(quality: 60);
      final file = _writeTempFile(bytes, 'test_no_inflate.jpg');
      addTearDown(file.deleteSync);

      final result = await service.compress(file.path, CompressionMode.smart);
      expect(result, isNotNull);
      expect(result!.compressedBytes, lessThanOrEqualTo(result.originalBytes));
      addTearDown(() => File(result.compressedPath).deleteSync());
    });

    test('returns null for non-existent file', () async {
      final result = await service.compress(
          '/nonexistent/path/file.jpg', CompressionMode.smart);
      expect(result, isNull);
    });

    test('returns null for invalid image bytes', () async {
      final file = _writeTempFile(
          Uint8List.fromList([0, 1, 2, 3, 4]), 'test_invalid.bin');
      addTearDown(file.deleteSync);

      final result = await service.compress(file.path, CompressionMode.smart);
      expect(result, isNull);
    });

    test('compressBatch processes all files and reports progress', () async {
      final files = List.generate(3, (i) {
        return _writeTempFile(_testJpeg(quality: 95), 'batch_$i.jpg');
      });
      addTearDown(() {
        for (final f in files) {
          if (f.existsSync()) f.deleteSync();
        }
      });

      int progressCalls = 0;
      final results = await service.compressBatch(
        files.map((f) => f.path).toList(),
        CompressionMode.smart,
        onProgress: (done, total) {
          progressCalls++;
          expect(done, lessThanOrEqualTo(total));
        },
      );

      expect(results.length, 3);
      expect(progressCalls, 3);
      for (final r in results) {
        addTearDown(() => File(r.compressedPath).deleteSync());
      }
    });

    test('savedPercent calculation is accurate', () async {
      final bytes = _testJpeg(width: 1000, height: 1000, quality: 100);
      final file = _writeTempFile(bytes, 'test_percent.jpg');
      addTearDown(file.deleteSync);

      final result =
          await service.compress(file.path, CompressionMode.aggressive);
      expect(result, isNotNull);
      addTearDown(() => File(result!.compressedPath).deleteSync());

      final expected = (result!.originalBytes - result.compressedBytes) /
          result.originalBytes *
          100;
      expect(result.savedPercent, closeTo(expected, 0.01));
    });
  });
}
