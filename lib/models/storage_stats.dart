class StorageStats {
  final int totalBytes;
  final int usedBytes;
  final int photoBytes;
  final int duplicateBytes;
  final int junkBytes;
  final int backedUpBytes;
  final int totalPhotos;
  final int duplicateCount;
  final int junkCount;

  const StorageStats({
    required this.totalBytes,
    required this.usedBytes,
    required this.photoBytes,
    required this.duplicateBytes,
    required this.junkBytes,
    required this.backedUpBytes,
    required this.totalPhotos,
    required this.duplicateCount,
    required this.junkCount,
  });

  double get usedPercent =>
      totalBytes > 0 ? usedBytes / totalBytes : 0;

  double get photoPercent =>
      totalBytes > 0 ? photoBytes / totalBytes : 0;

  int get reclaimableBytes => duplicateBytes + junkBytes + backedUpBytes;

  double get reclaimableMB => reclaimableBytes / (1024 * 1024);
  double get usedGB => usedBytes / (1024 * 1024 * 1024);
  double get totalGB => totalBytes / (1024 * 1024 * 1024);

  static const StorageStats empty = StorageStats(
    totalBytes: 0,
    usedBytes: 0,
    photoBytes: 0,
    duplicateBytes: 0,
    junkBytes: 0,
    backedUpBytes: 0,
    totalPhotos: 0,
    duplicateCount: 0,
    junkCount: 0,
  );
}
