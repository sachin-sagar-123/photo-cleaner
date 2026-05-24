enum CompressionMode { lossless, smart, aggressive }

class CompressionResult {
  final String originalPath;
  final String compressedPath;
  final int originalBytes;
  final int compressedBytes;
  final CompressionMode mode;

  const CompressionResult({
    required this.originalPath,
    required this.compressedPath,
    required this.originalBytes,
    required this.compressedBytes,
    required this.mode,
  });

  double get savedBytes => (originalBytes - compressedBytes).toDouble();
  double get savedPercent =>
      originalBytes > 0 ? savedBytes / originalBytes * 100 : 0;
  double get savedMB => savedBytes / (1024 * 1024);
}
