import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/models/models.dart';

PhotoAsset _asset({
  String id = 'test-1',
  String path = '/photos/test.jpg',
  String name = 'test.jpg',
  int sizeBytes = 2 * 1024 * 1024,
  List<QualityIssue> issues = const [],
  PhotoCategory category = PhotoCategory.other,
  bool isBackedUp = false,
  String? pHash,
  String? dHash,
  String? driveFileId,
  String? driveMd5,
  bool isDriveOnly = false,
}) =>
    PhotoAsset(
      id: id,
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      createdAt: DateTime(2024, 1, 1),
      issues: issues,
      category: category,
      isBackedUp: isBackedUp,
      pHash: pHash,
      dHash: dHash,
      driveFileId: driveFileId,
      driveMd5: driveMd5,
      isDriveOnly: isDriveOnly,
    );

void main() {
  group('StorageStats', () {
    test('empty stats has zero values', () {
      expect(StorageStats.empty.totalPhotos, 0);
      expect(StorageStats.empty.reclaimableBytes, 0);
      expect(StorageStats.empty.usedPercent, 0.0);
    });

    test('reclaimableBytes sums duplicates + junk + backedUp', () {
      const stats = StorageStats(
        totalBytes: 100,
        usedBytes: 80,
        photoBytes: 80,
        duplicateBytes: 10,
        junkBytes: 5,
        backedUpBytes: 15,
        totalPhotos: 100,
        duplicateCount: 5,
        junkCount: 3,
      );
      expect(stats.reclaimableBytes, 30);
    });

    test('usedPercent is correct ratio', () {
      const stats = StorageStats(
        totalBytes: 1000,
        usedBytes: 250,
        photoBytes: 250,
        duplicateBytes: 0,
        junkBytes: 0,
        backedUpBytes: 0,
        totalPhotos: 10,
        duplicateCount: 0,
        junkCount: 0,
      );
      expect(stats.usedPercent, closeTo(0.25, 0.001));
    });

    test('usedPercent is 0 when totalBytes is 0', () {
      expect(StorageStats.empty.usedPercent, 0.0);
    });

    test('reclaimableMB converts correctly', () {
      const stats = StorageStats(
        totalBytes: 1000000000,
        usedBytes: 500000000,
        photoBytes: 500000000,
        duplicateBytes: 10 * 1024 * 1024,
        junkBytes: 0,
        backedUpBytes: 0,
        totalPhotos: 50,
        duplicateCount: 5,
        junkCount: 0,
      );
      expect(stats.reclaimableMB, closeTo(10.0, 0.01));
    });
  });

  group('PhotoAsset', () {
    test('hasIssues is true when issues list is non-empty', () {
      final asset = _asset(issues: [QualityIssue.blurry, QualityIssue.duplicate]);
      expect(asset.hasIssues, isTrue);
    });

    test('hasIssues is false for empty issues', () {
      expect(_asset().hasIssues, isFalse);
    });

    test('isDuplicate detects duplicate issue', () {
      final asset = _asset(issues: [QualityIssue.duplicate]);
      expect(asset.isDuplicate, isTrue);
    });

    test('isBlurry detects blurry issue', () {
      final asset = _asset(issues: [QualityIssue.blurry]);
      expect(asset.isBlurry, isTrue);
    });

    test('isJunk detects junk issue', () {
      final asset = _asset(issues: [QualityIssue.junk]);
      expect(asset.isJunk, isTrue);
    });

    test('sizeMB converts correctly', () {
      final asset = _asset(sizeBytes: 2 * 1024 * 1024);
      expect(asset.sizeMB, closeTo(2.0, 0.001));
    });

    test('isLocal is true when path is non-empty', () {
      expect(_asset(path: '/photos/test.jpg').isLocal, isTrue);
    });

    test('isLocal is false for Drive-only asset', () {
      expect(_asset(path: '', isDriveOnly: true).isLocal, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final original = _asset(
        issues: [QualityIssue.blurry],
        pHash: 'abc123',
      );
      final copy = original.copyWith(isBackedUp: true);
      expect(copy.id, original.id);
      expect(copy.path, original.path);
      expect(copy.isBackedUp, isTrue);
      expect(copy.issues, original.issues);
      expect(copy.pHash, original.pHash);
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      final original = _asset(
        id: 'rt-1',
        category: PhotoCategory.food,
        issues: [QualityIssue.blurry],
        isBackedUp: true,
        pHash: 'abc123',
        dHash: 'def456',
        driveFileId: 'drive-id-1',
        driveMd5: 'md5hash',
        isDriveOnly: false,
      );
      final map = original.toMap();
      final restored = PhotoAsset.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.category, original.category);
      expect(restored.issues, original.issues);
      expect(restored.isBackedUp, original.isBackedUp);
      expect(restored.pHash, original.pHash);
      expect(restored.dHash, original.dHash);
      expect(restored.driveFileId, original.driveFileId);
      expect(restored.driveMd5, original.driveMd5);
      expect(restored.isDriveOnly, original.isDriveOnly);
      // createdAt round-trips through millisecondsSinceEpoch
      expect(restored.createdAt.millisecondsSinceEpoch,
          original.createdAt.millisecondsSinceEpoch);
    });

    test('fromMap handles null optional fields', () {
      final map = _asset().toMap()
        ..['p_hash'] = null
        ..['d_hash'] = null
        ..['drive_file_id'] = null
        ..['drive_md5'] = null
        ..['suggested_name'] = null
        ..['issues'] = '';
      final asset = PhotoAsset.fromMap(map);
      expect(asset.pHash, isNull);
      expect(asset.dHash, isNull);
      expect(asset.issues, isEmpty);
    });
  });

  group('DuplicateGroup', () {
    late List<PhotoAsset> assets;

    setUp(() {
      assets = [
        _asset(id: 'a', sizeBytes: 3000000),
        _asset(id: 'b', sizeBytes: 1000000),
      ];
    });

    test('bestAsset is the largest file', () {
      final group = DuplicateGroup(
          groupId: 'g1', assets: assets, similarity: 0.95);
      expect(group.bestAsset.id, 'a');
    });

    test('duplicates excludes bestAsset', () {
      final group = DuplicateGroup(
          groupId: 'g1', assets: assets, similarity: 0.95);
      expect(group.duplicates.length, 1);
      expect(group.duplicates.first.id, 'b');
    });

    test('wastedBytes sums duplicate sizes', () {
      final group = DuplicateGroup(
          groupId: 'g1', assets: assets, similarity: 0.95);
      expect(group.wastedBytes, 1000000);
    });

    test('wastedMB converts correctly', () {
      final group = DuplicateGroup(
          groupId: 'g1', assets: assets, similarity: 0.95);
      expect(group.wastedMB, closeTo(1000000 / (1024 * 1024), 0.001));
    });
  });

  group('CompressionResult', () {
    const result = CompressionResult(
      originalPath: '/orig.jpg',
      compressedPath: '/comp.jpg',
      originalBytes: 1000000,
      compressedBytes: 400000,
      mode: CompressionMode.smart,
    );

    test('savedBytes is correct', () {
      expect(result.savedBytes, 600000.0);
    });

    test('savedPercent is correct', () {
      expect(result.savedPercent, closeTo(60.0, 0.01));
    });

    test('savedMB converts correctly', () {
      expect(result.savedMB, closeTo(600000 / (1024 * 1024), 0.001));
    });
  });
}
