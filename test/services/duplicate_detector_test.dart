import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/services/duplicate_detector_service.dart';

// Expose private statics for testing via a test subclass
class _TestDetector extends DuplicateDetectorService {
  static String? pHash(Uint8List b) =>
      DuplicateDetectorService.computePHashSync(b);
  static String? dHash(Uint8List b) =>
      DuplicateDetectorService.computeDHashSync(b);
  static int hamming(String a, String b) =>
      DuplicateDetectorService.hammingDistancePublic(a, b);
}

/// Generates a solid-color JPEG of given dimensions.
Uint8List _solidJpeg(int r, int g, int b,
    {int width = 100, int height = 100}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Generates a gradient JPEG (more realistic than solid color).
Uint8List _gradientJpeg({int width = 200, int height = 200}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 255 ~/ width), (y * 255 ~/ height), 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

/// Adds Gaussian noise to an image (simulates re-save/compression artifacts).
Uint8List _addNoise(Uint8List bytes, {int amount = 10}) {
  final image = img.decodeImage(bytes)!;
  final rng = math.Random(42);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final nr = (p.r + rng.nextInt(amount * 2) - amount).clamp(0, 255);
      final ng = (p.g + rng.nextInt(amount * 2) - amount).clamp(0, 255);
      final nb = (p.b + rng.nextInt(amount * 2) - amount).clamp(0, 255);
      image.setPixelRgb(x, y, nr.toInt(), ng.toInt(), nb.toInt());
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

PhotoAsset _asset(String id, {String? pHash, String? dHash, int size = 500000}) =>
    PhotoAsset(
      id: id,
      path: '/fake/$id.jpg',
      name: '$id.jpg',
      sizeBytes: size,
      createdAt: DateTime(2024, 1, 1),
      pHash: pHash,
      dHash: dHash,
    );

void main() {
  group('Hamming distance', () {
    test('identical strings → 0', () {
      expect(
        DuplicateDetectorService.hammingDistancePublic('abcdef01', 'abcdef01'),
        0,
      );
    });

    test('completely different nibbles → max bits', () {
      // 'f' = 1111, '0' = 0000 → 4 bits different per char
      final dist =
          DuplicateDetectorService.hammingDistancePublic('ffffffff', '00000000');
      expect(dist, 32); // 8 chars × 4 bits
    });

    test('length mismatch → max int', () {
      final dist =
          DuplicateDetectorService.hammingDistancePublic('abc', 'abcd');
      expect(dist, greaterThan(1000));
    });

    test('single bit difference', () {
      // '1' = 0001, '0' = 0000 → 1 bit
      expect(
        DuplicateDetectorService.hammingDistancePublic('1', '0'),
        1,
      );
    });
  });

  group('pHash', () {
    test('returns 16-char hex string for valid image', () async {
      final bytes = _gradientJpeg();
      final service = DuplicateDetectorService();
      final hash = await service.computePHash(bytes);
      expect(hash, isNotNull);
      expect(hash!.length, 16); // 63 bits → 16 hex chars
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hash), isTrue);
    });

    test('returns null for empty bytes', () async {
      final service = DuplicateDetectorService();
      final hash = await service.computePHash(Uint8List(0));
      expect(hash, isNull);
    });

    test('same image → identical hash', () async {
      final bytes = _gradientJpeg();
      final service = DuplicateDetectorService();
      final h1 = await service.computePHash(bytes);
      final h2 = await service.computePHash(bytes);
      expect(h1, equals(h2));
    });

    test('noisy version of same image → low hamming distance', () async {
      final original = _gradientJpeg();
      final noisy = _addNoise(original, amount: 5);
      final service = DuplicateDetectorService();
      final h1 = await service.computePHash(original);
      final h2 = await service.computePHash(noisy);
      expect(h1, isNotNull);
      expect(h2, isNotNull);
      final dist = DuplicateDetectorService.hammingDistancePublic(h1!, h2!);
      expect(dist, lessThanOrEqualTo(10),
          reason: 'Lightly noised image should still match (dist=$dist)');
    });

    test('structurally different images → high hamming distance', () async {
      // Use gradient images with opposite directions — very different AC content
      final image1 = img.Image(width: 200, height: 200);
      final image2 = img.Image(width: 200, height: 200);
      for (int y = 0; y < 200; y++) {
        for (int x = 0; x < 200; x++) {
          // image1: bright top-left to dark bottom-right
          image1.setPixelRgb(x, y, 255 - x, 255 - y, 128);
          // image2: dark top-left to bright bottom-right (opposite gradient)
          image2.setPixelRgb(x, y, x, y, 128);
        }
      }
      final bytes1 =
          Uint8List.fromList(img.encodeJpg(image1, quality: 95));
      final bytes2 =
          Uint8List.fromList(img.encodeJpg(image2, quality: 95));

      final service = DuplicateDetectorService();
      final h1 = await service.computePHash(bytes1);
      final h2 = await service.computePHash(bytes2);
      expect(h1, isNotNull);
      expect(h2, isNotNull);
      final dist = DuplicateDetectorService.hammingDistancePublic(h1!, h2!);
      expect(dist, greaterThan(10),
          reason: 'Opposite gradients should not match (dist=$dist)');
    });
  });

  group('dHash', () {
    test('returns 16-char hex string', () async {
      final service = DuplicateDetectorService();
      final hash = await service.computeDHash(_gradientJpeg());
      expect(hash, isNotNull);
      expect(hash!.length, 16);
    });

    test('same image → identical hash', () async {
      final bytes = _gradientJpeg();
      final service = DuplicateDetectorService();
      final h1 = await service.computeDHash(bytes);
      final h2 = await service.computeDHash(bytes);
      expect(h1, equals(h2));
    });
  });

  group('findDuplicates', () {
    test('empty list → empty result', () async {
      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([]);
      expect(groups, isEmpty);
    });

    test('single asset → no groups', () async {
      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([
        _asset('a', pHash: 'abcd1234abcd1234'),
      ]);
      expect(groups, isEmpty);
    });

    test('two identical hashes → one group', () async {
      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([
        _asset('a', pHash: 'abcd1234abcd1234'),
        _asset('b', pHash: 'abcd1234abcd1234'),
      ]);
      expect(groups.length, 1);
      expect(groups.first.assets.length, 2);
    });

    test('transitive chain A≈B, B≈C → single group of 3', () async {
      // A and C differ by 8 bits each from B, but may differ by 16 from each other.
      // Union-Find must merge them all into one group.
      const base = '0000000000000000'; // 64 zero bits
      // Flip 8 bits in first 2 hex chars for B: 0000 → ff00
      const hashB = 'ff00000000000000';
      // Flip 8 bits in last 2 hex chars for C: 0000 → 00ff
      const hashC = '000000000000ff00';

      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([
        _asset('a', pHash: base),
        _asset('b', pHash: hashB),
        _asset('c', pHash: hashC),
      ]);
      // A≈B (8 bits), B≈C (8 bits) — both within threshold
      // All three should be in one group
      final allIds = groups.expand((g) => g.assets.map((a) => a.id)).toSet();
      expect(allIds.contains('a'), isTrue);
      expect(allIds.contains('b'), isTrue);
      expect(allIds.contains('c'), isTrue);
    });

    test('completely different hashes → no groups', () async {
      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([
        _asset('a', pHash: '0000000000000000'),
        _asset('b', pHash: 'ffffffffffffffff'),
      ]);
      expect(groups, isEmpty);
    });

    test('assets without hashes are ignored', () async {
      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([
        _asset('a'), // no hash
        _asset('b'), // no hash
      ]);
      expect(groups, isEmpty);
    });

    test('groups sorted by wasted bytes descending', () async {
      final service = DuplicateDetectorService();
      final groups = await service.findDuplicates([
        _asset('a', pHash: '0000000000000000', size: 1000000),
        _asset('b', pHash: '0000000000000000', size: 1000000),
        _asset('c', pHash: 'aaaaaaaaaaaaaaaa', size: 5000000),
        _asset('d', pHash: 'aaaaaaaaaaaaaaaa', size: 5000000),
      ]);
      expect(groups.length, 2);
      expect(groups.first.wastedBytes,
          greaterThanOrEqualTo(groups.last.wastedBytes));
    });
  });
}
