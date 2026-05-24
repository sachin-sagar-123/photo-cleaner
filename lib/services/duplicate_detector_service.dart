import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/models.dart';

/// Perceptual duplicate detection using pHash (DCT-based) and dHash (gradient).
///
/// Pipeline:
///   1. computePHash / computeDHash — called per-image during scan, run in isolate
///   2. findDuplicates — called once after scan, groups by size bucket then hash
///
/// Size-bucket pre-filtering reduces O(n²) comparisons: photos that differ in
/// size by more than 2× are almost never perceptual duplicates.
class DuplicateDetectorService {
  // pHash: 64-bit hash from 8×8 DCT of 32×32 grayscale image
  static const int _pHashSize = 8;
  // dHash: 64-bit hash from 9×8 horizontal gradient of grayscale image
  static const int _dHashCols = 9;
  static const int _dHashRows = 8;

  // Size bucket width: 1 MB. Photos within the same or adjacent buckets
  // are candidates for comparison.
  static const int _sizeBucketBytes = 1024 * 1024;

  // Hamming distance threshold: ≤10 bits different out of 64 → duplicate.
  // Empirically: identical photos score 0, same photo different compression
  // scores 2–8, different photos score >20.
  static const int _hammingThreshold = 10;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<String?> computePHash(Uint8List bytes) async {
    return Isolate.run(() => _computePHash(bytes));
  }

  Future<String?> computeDHash(Uint8List bytes) async {
    return Isolate.run(() => _computeDHash(bytes));
  }

  Future<List<DuplicateGroup>> findDuplicates(List<PhotoAsset> assets) async {
    return Isolate.run(() => _findDuplicates(assets));
  }

  // ── pHash ─────────────────────────────────────────────────────────────────

  static String? _computePHash(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;

    // Resize to 32×32 for DCT input
    final resized = img.copyResize(image, width: 32, height: 32);
    final gray = img.grayscale(resized);

    final pixels = List.generate(
      32,
      (y) => List.generate(32, (x) => img.getLuminance(gray.getPixel(x, y)).toDouble()),
    );

    final dct = _dct2d(pixels);

    // Extract top-left 8×8 low-frequency block (skip DC component at [0][0]
    // which encodes overall brightness and causes false matches)
    double sum = 0;
    final flat = <double>[];
    for (int y = 0; y < _pHashSize; y++) {
      for (int x = 0; x < _pHashSize; x++) {
        // Skip DC component to make hash brightness-invariant
        if (x == 0 && y == 0) continue;
        flat.add(dct[y][x]);
        sum += dct[y][x];
      }
    }
    if (flat.isEmpty) return null;
    final mean = sum / flat.length;

    final bits = flat.map((v) => v >= mean ? '1' : '0').join();
    return _bitsToHex(bits);
  }

  // ── dHash ─────────────────────────────────────────────────────────────────

  static String? _computeDHash(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;

    final resized = img.copyResize(image, width: _dHashCols, height: _dHashRows);
    final gray = img.grayscale(resized);

    final bits = StringBuffer();
    for (int y = 0; y < _dHashRows; y++) {
      for (int x = 0; x < _dHashCols - 1; x++) {
        final left = img.getLuminance(gray.getPixel(x, y));
        final right = img.getLuminance(gray.getPixel(x + 1, y));
        bits.write(left < right ? '1' : '0');
      }
    }
    return _bitsToHex(bits.toString());
  }

  // ── Duplicate grouping ────────────────────────────────────────────────────

  /// Groups assets into duplicate sets.
  ///
  /// Algorithm:
  ///   1. Bucket assets by file size (1 MB buckets)
  ///   2. For each asset, compare against all assets in same + adjacent buckets
  ///   3. Use Union-Find to correctly merge transitive duplicate chains
  ///      (A≈B, B≈C → group {A,B,C})
  static List<DuplicateGroup> _findDuplicates(List<PhotoAsset> assets) {
    // Filter to assets that have at least one hash
    final hashable = assets
        .where((a) => a.pHash != null || a.dHash != null)
        .toList();

    if (hashable.length < 2) return [];

    // Build size buckets
    final buckets = <int, List<int>>{}; // bucket → list of indices into hashable
    for (int i = 0; i < hashable.length; i++) {
      final bucket = hashable[i].sizeBytes ~/ _sizeBucketBytes;
      buckets.putIfAbsent(bucket, () => []).add(i);
    }

    // Union-Find for transitive grouping
    final parent = List<int>.generate(hashable.length, (i) => i);

    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]]; // path compression
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      final ra = find(a), rb = find(b);
      if (ra != rb) parent[ra] = rb;
    }

    // Compare within same bucket and adjacent buckets
    final processedPairs = <String>{};

    for (final entry in buckets.entries) {
      final bucket = entry.key;
      // Collect indices from this bucket and adjacent bucket
      final candidates = <int>[
        ...?buckets[bucket],
        ...?buckets[bucket + 1],
      ];

      for (int i = 0; i < candidates.length; i++) {
        for (int j = i + 1; j < candidates.length; j++) {
          final ai = candidates[i];
          final bi = candidates[j];
          // Avoid processing same pair twice (from adjacent bucket overlap)
          final pairKey = ai < bi ? '$ai:$bi' : '$bi:$ai';
          if (processedPairs.contains(pairKey)) continue;
          processedPairs.add(pairKey);

          if (_areSimilar(hashable[ai], hashable[bi])) {
            union(ai, bi);
          }
        }
      }
    }

    // Collect groups from Union-Find roots
    final groupMap = <int, List<PhotoAsset>>{};
    for (int i = 0; i < hashable.length; i++) {
      final root = find(i);
      groupMap.putIfAbsent(root, () => []).add(hashable[i]);
    }

    return groupMap.values
        .where((g) => g.length > 1)
        .map((g) => DuplicateGroup(
              groupId: g.first.id,
              assets: g,
              similarity: _groupSimilarity(g),
            ))
        .toList()
      ..sort((a, b) => b.wastedBytes.compareTo(a.wastedBytes)); // largest waste first
  }

  static bool _areSimilar(PhotoAsset a, PhotoAsset b) {
    // pHash is more reliable for perceptual similarity — check first
    if (a.pHash != null && b.pHash != null) {
      if (_hammingDistance(a.pHash!, b.pHash!) <= _hammingThreshold) return true;
    }
    // dHash as fallback — good for near-identical crops/resizes
    if (a.dHash != null && b.dHash != null) {
      if (_hammingDistance(a.dHash!, b.dHash!) <= _hammingThreshold) return true;
    }
    return false;
  }

  static double _groupSimilarity(List<PhotoAsset> assets) {
    if (assets.length < 2) return 1.0;
    final a = assets[0];
    final b = assets[1];
    if (a.pHash != null && b.pHash != null) {
      final dist = _hammingDistance(a.pHash!, b.pHash!);
      // pHash is 63 bits (we skip DC), normalize to 0–1
      return 1.0 - (dist / 63.0).clamp(0.0, 1.0);
    }
    if (a.dHash != null && b.dHash != null) {
      final dist = _hammingDistance(a.dHash!, b.dHash!);
      return 1.0 - (dist / 64.0).clamp(0.0, 1.0);
    }
    return 0.9;
  }

  // ── Public test-accessible statics ───────────────────────────────────────

  /// Synchronous pHash for testing (no isolate).
  static String? computePHashSync(Uint8List bytes) => _computePHash(bytes);

  /// Synchronous dHash for testing (no isolate).
  static String? computeDHashSync(Uint8List bytes) => _computeDHash(bytes);

  /// Public wrapper for hamming distance (for testing).
  static int hammingDistancePublic(String a, String b) =>
      _hammingDistance(a, b);

  // ── Pre-decoded image variants for batch processing ─────────────────────
  // These skip the decode step when the caller already has an img.Image.

  /// Compute pHash from a pre-decoded image.
  static String? computePHashFromImage(img.Image image) {
    final resized = img.copyResize(image, width: 32, height: 32);
    final gray = img.grayscale(resized);

    final pixels = List.generate(
      32,
      (y) => List.generate(
          32, (x) => img.getLuminance(gray.getPixel(x, y)).toDouble()),
    );

    final dct = _dct2d(pixels);

    double sum = 0;
    final flat = <double>[];
    for (int y = 0; y < _pHashSize; y++) {
      for (int x = 0; x < _pHashSize; x++) {
        if (x == 0 && y == 0) continue;
        flat.add(dct[y][x]);
        sum += dct[y][x];
      }
    }
    if (flat.isEmpty) return null;
    final mean = sum / flat.length;

    final bits = flat.map((v) => v >= mean ? '1' : '0').join();
    return _bitsToHex(bits);
  }

  /// Compute dHash from a pre-decoded image.
  static String? computeDHashFromImage(img.Image image) {
    final resized =
        img.copyResize(image, width: _dHashCols, height: _dHashRows);
    final gray = img.grayscale(resized);

    final bits = StringBuffer();
    for (int y = 0; y < _dHashRows; y++) {
      for (int x = 0; x < _dHashCols - 1; x++) {
        final left = img.getLuminance(gray.getPixel(x, y));
        final right = img.getLuminance(gray.getPixel(x + 1, y));
        bits.write(left < right ? '1' : '0');
      }
    }
    return _bitsToHex(bits.toString());
  }

  // ── Hash utilities ────────────────────────────────────────────────────────

  /// Counts differing bits between two hex strings.
  /// Returns max int on length mismatch (treat as completely different).
  static int _hammingDistance(String hexA, String hexB) {
    if (hexA.length != hexB.length) return 0x7fffffff;
    int dist = 0;
    for (int i = 0; i < hexA.length; i++) {
      final a = int.tryParse(hexA[i], radix: 16) ?? 0;
      final b = int.tryParse(hexB[i], radix: 16) ?? 0;
      // Brian Kernighan's bit count
      int xor = a ^ b;
      while (xor != 0) {
        xor &= xor - 1;
        dist++;
      }
    }
    return dist;
  }

  static String _bitsToHex(String bits) {
    final buffer = StringBuffer();
    for (int i = 0; i < bits.length; i += 4) {
      final end = math.min(i + 4, bits.length);
      final chunk = bits.substring(i, end).padRight(4, '0');
      buffer.write(int.parse(chunk, radix: 2).toRadixString(16));
    }
    return buffer.toString();
  }

  // ── DCT implementation ────────────────────────────────────────────────────

  /// 2D DCT via separable 1D DCT (row-then-column).
  static List<List<double>> _dct2d(List<List<double>> pixels) {
    final n = pixels.length;
    // Row-wise DCT
    final rowDct = pixels.map((row) => _dct1d(row)).toList();
    // Column-wise DCT
    final result = List.generate(n, (_) => List<double>.filled(n, 0.0));
    for (int x = 0; x < n; x++) {
      final col = List.generate(n, (y) => rowDct[y][x]);
      final colDct = _dct1d(col);
      for (int y = 0; y < n; y++) {
        result[y][x] = colDct[y];
      }
    }
    return result;
  }

  /// Type-II DCT using dart:math cos — accurate for all input ranges.
  /// O(n²) which is fine for n=32 (1024 operations per row/column).
  static List<double> _dct1d(List<double> input) {
    final n = input.length;
    final pi = math.pi;
    return List.generate(n, (k) {
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        sum += input[i] * math.cos(pi * k * (2 * i + 1) / (2 * n));
      }
      // Orthonormal scaling
      final scale = k == 0
          ? math.sqrt(1.0 / n)
          : math.sqrt(2.0 / n);
      return sum * scale;
    });
  }
}
