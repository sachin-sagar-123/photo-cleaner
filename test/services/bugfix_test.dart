import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/services/scanner_service.dart';

PhotoAsset _asset({
  String id = 'test-1',
  String path = '/photos/test.jpg',
  String name = 'test.jpg',
  int sizeBytes = 2 * 1024 * 1024,
  List<QualityIssue> issues = const [],
  PhotoCategory category = PhotoCategory.other,
  bool isBackedUp = false,
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
    );

void main() {
  // ── Bug #1: Integer overflow in totalBytes ──────────────────────────────

  group('Integer overflow fix', () {
    test('64 GB constant equals expected value', () {
      // 64 * 1024 * 1024 * 1024 = 68,719,476,736
      // This would overflow 32-bit int (max 2,147,483,647)
      const totalBytes = 68719476736;
      expect(totalBytes, equals(64 * 1024 * 1024 * 1024));
      expect(totalBytes, greaterThan(0));
      // Verify it's actually 64 GB
      expect(totalBytes / (1024 * 1024 * 1024), equals(64));
    });

    test('StorageStats percentages are correct with 64 GB total', () {
      const totalBytes = 68719476736;
      const usedBytes = 34359738368; // 32 GB
      const stats = StorageStats(
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        photoBytes: usedBytes,
        duplicateBytes: 0,
        junkBytes: 0,
        backedUpBytes: 0,
        totalPhotos: 100,
        duplicateCount: 0,
        junkCount: 0,
      );
      expect(stats.usedPercent, closeTo(0.5, 0.001));
      expect(stats.usedGB, closeTo(32.0, 0.01));
      expect(stats.totalGB, closeTo(64.0, 0.01));
    });
  });

  // ── Bug #2: ScanState.copyWith can't clear nullable fields ─────────────

  group('ScanState.copyWith sentinel pattern', () {
    test('can clear error to null', () {
      const stateWithError = ScanState(error: 'something failed');
      final cleared = stateWithError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('can clear progress to null', () {
      const progress = ScanProgress(scanned: 5, total: 10, currentFile: 'x');
      const stateWithProgress = ScanState(progress: progress);
      final cleared = stateWithProgress.copyWith(progress: null);
      expect(cleared.progress, isNull);
    });

    test('omitting error preserves existing error', () {
      const stateWithError = ScanState(error: 'something failed');
      final updated = stateWithError.copyWith(isScanning: true);
      expect(updated.error, equals('something failed'));
    });

    test('omitting progress preserves existing progress', () {
      const progress = ScanProgress(scanned: 5, total: 10, currentFile: 'x');
      const stateWithProgress = ScanState(progress: progress);
      final updated = stateWithProgress.copyWith(isScanning: true);
      expect(updated.progress, equals(progress));
    });

    test('can set error to a new value', () {
      const stateWithError = ScanState(error: 'old error');
      final updated = stateWithError.copyWith(error: 'new error');
      expect(updated.error, equals('new error'));
    });

    test('full scan lifecycle: start → progress → complete clears state', () {
      // Start scan: clear previous error and progress
      var state = const ScanState(error: 'old error');
      state = state.copyWith(isScanning: true, error: null, progress: null);
      expect(state.isScanning, isTrue);
      expect(state.error, isNull);
      expect(state.progress, isNull);

      // Progress update
      const progress = ScanProgress(scanned: 3, total: 10, currentFile: 'a.jpg');
      state = state.copyWith(progress: progress);
      expect(state.progress, equals(progress));

      // Complete
      state = state.copyWith(isScanning: false);
      expect(state.isScanning, isFalse);
      expect(state.progress, equals(progress)); // preserved
      expect(state.error, isNull); // stays null
    });
  });

  // ── Bug #2b: DriveScanState.copyWith same issue ────────────────────────

  group('DriveScanState.copyWith sentinel pattern', () {
    test('can clear error to null', () {
      const stateWithError = DriveScanState(error: 'drive error');
      final cleared = stateWithError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('can clear progress to null', () {
      const progress = DriveScanProgress(
          scanned: 5, total: 10, currentFile: 'x', phase: 'analyzing');
      const stateWithProgress = DriveScanState(progress: progress);
      final cleared = stateWithProgress.copyWith(progress: null);
      expect(cleared.progress, isNull);
    });

    test('omitting error preserves existing error', () {
      const stateWithError = DriveScanState(error: 'drive error');
      final updated = stateWithError.copyWith(isScanning: true);
      expect(updated.error, equals('drive error'));
    });

    test('re-scan clears previous error and progress', () {
      const stateWithError = DriveScanState(
        error: 'old error',
        completed: true,
      );
      final restarted = stateWithError.copyWith(
        isScanning: true,
        error: null,
        progress: null,
        completed: false,
      );
      expect(restarted.isScanning, isTrue);
      expect(restarted.error, isNull);
      expect(restarted.progress, isNull);
      expect(restarted.completed, isFalse);
    });
  });

  // ── Bug #8: PhotoCategory enum bounds ──────────────────────────────────

  group('PhotoCategory enum bounds', () {
    test('PhotoCategory.other has index 5', () {
      expect(PhotoCategory.other.index, equals(5));
    });

    test('PhotoCategory.values has exactly 6 entries (0-5)', () {
      expect(PhotoCategory.values.length, equals(6));
    });

    test('index 5 maps to PhotoCategory.other (DB DEFAULT)', () {
      expect(PhotoCategory.values[5], equals(PhotoCategory.other));
    });

    test('index 6 would throw RangeError', () {
      expect(() => PhotoCategory.values[6], throwsRangeError);
    });

    test('all category indices are valid for DB round-trip', () {
      for (final cat in PhotoCategory.values) {
        expect(cat.index, lessThan(PhotoCategory.values.length));
        expect(PhotoCategory.values[cat.index], equals(cat));
      }
    });
  });

  // ── Bug #5/#6: Delete with stale selection ─────────────────────────────

  group('Safe photo lookup (firstOrNull pattern)', () {
    test('firstOrNull returns null for missing ID', () {
      final photos = [
        _asset(id: 'a'),
        _asset(id: 'b'),
      ];
      final result = photos.where((p) => p.id == 'missing').firstOrNull;
      expect(result, isNull);
    });

    test('firstOrNull returns correct photo for valid ID', () {
      final photos = [
        _asset(id: 'a'),
        _asset(id: 'b'),
      ];
      final result = photos.where((p) => p.id == 'b').firstOrNull;
      expect(result, isNotNull);
      expect(result!.id, equals('b'));
    });

    test('empty path is skipped for file deletion', () {
      final driveOnly = _asset(id: 'drive-1', path: '');
      expect(driveOnly.path.isEmpty, isTrue);
      expect(driveOnly.isLocal, isFalse);
    });
  });

  // ── Bug #16: usedPercent naming vs value ────────────────────────────────

  group('StorageStats percentage calculations', () {
    test('usedPercent returns ratio (0-1), not percentage (0-100)', () {
      const stats = StorageStats(
        totalBytes: 1000,
        usedBytes: 500,
        photoBytes: 500,
        duplicateBytes: 0,
        junkBytes: 0,
        backedUpBytes: 0,
        totalPhotos: 10,
        duplicateCount: 0,
        junkCount: 0,
      );
      // usedPercent is a ratio, not a percentage
      expect(stats.usedPercent, closeTo(0.5, 0.001));
      expect(stats.usedPercent, lessThanOrEqualTo(1.0));
    });

    test('photoPercent returns ratio (0-1)', () {
      const stats = StorageStats(
        totalBytes: 1000,
        usedBytes: 500,
        photoBytes: 250,
        duplicateBytes: 0,
        junkBytes: 0,
        backedUpBytes: 0,
        totalPhotos: 10,
        duplicateCount: 0,
        junkCount: 0,
      );
      expect(stats.photoPercent, closeTo(0.25, 0.001));
    });
  });

  // ── Bug: DuplicateGroup with empty assets list ─────────────────────────

  group('DuplicateGroup edge cases', () {
    test('bestAsset works with single asset', () {
      final group = DuplicateGroup(
        groupId: 'g1',
        assets: [_asset(id: 'only', sizeBytes: 1000)],
        similarity: 1.0,
      );
      expect(group.bestAsset.id, equals('only'));
      expect(group.duplicates, isEmpty);
      expect(group.wastedBytes, equals(0));
    });

    test('bestAsset picks largest when sizes differ', () {
      final group = DuplicateGroup(
        groupId: 'g1',
        assets: [
          _asset(id: 'small', sizeBytes: 100),
          _asset(id: 'large', sizeBytes: 9999),
          _asset(id: 'medium', sizeBytes: 500),
        ],
        similarity: 0.95,
      );
      expect(group.bestAsset.id, equals('large'));
      expect(group.duplicates.length, equals(2));
      expect(group.wastedBytes, equals(600)); // 100 + 500
    });

    test('bestAsset picks first when sizes are equal', () {
      final group = DuplicateGroup(
        groupId: 'g1',
        assets: [
          _asset(id: 'a', sizeBytes: 1000),
          _asset(id: 'b', sizeBytes: 1000),
        ],
        similarity: 0.95,
      );
      // reduce picks first when equal (>=)
      expect(group.bestAsset.id, equals('a'));
    });
  });

  // ── CompressionResult edge cases ───────────────────────────────────────

  group('CompressionResult edge cases', () {
    test('savedPercent is 0 when originalBytes is 0', () {
      const result = CompressionResult(
        originalPath: '/a.jpg',
        compressedPath: '/b.jpg',
        originalBytes: 0,
        compressedBytes: 0,
        mode: CompressionMode.smart,
      );
      expect(result.savedPercent, equals(0));
    });

    test('savedBytes is negative when compressed is larger', () {
      const result = CompressionResult(
        originalPath: '/a.jpg',
        compressedPath: '/b.jpg',
        originalBytes: 100,
        compressedBytes: 200,
        mode: CompressionMode.lossless,
      );
      // savedBytes = original - compressed = -100
      expect(result.savedBytes, equals(-100.0));
      expect(result.savedPercent, equals(-100.0));
    });
  });

  // ── VaultDocument round-trip ───────────────────────────────────────────

  group('VaultDocument', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final doc = VaultDocument(
        id: 'v1',
        title: 'Passport',
        imagePath: '/vault/v1.jpg',
        type: DocumentType.passport,
        addedAt: DateTime(2024, 6, 15),
        notes: 'Expires 2030',
        tags: ['travel', 'id'],
      );
      final map = doc.toMap();
      final restored = VaultDocument.fromMap(map);
      expect(restored.id, equals(doc.id));
      expect(restored.title, equals(doc.title));
      expect(restored.type, equals(doc.type));
      expect(restored.notes, equals(doc.notes));
      expect(restored.tags, equals(doc.tags));
    });

    test('fromMap handles empty tags string', () {
      final map = VaultDocument(
        id: 'v2',
        title: 'Receipt',
        imagePath: '/vault/v2.jpg',
        type: DocumentType.receipt,
        addedAt: DateTime(2024, 1, 1),
      ).toMap();
      // tags field is empty string when no tags
      final restored = VaultDocument.fromMap(map);
      expect(restored.tags, isEmpty);
    });

    test('DocumentType.other has index 5 (matches DB DEFAULT)', () {
      expect(DocumentType.other.index, equals(5));
      expect(DocumentType.values.length, equals(6));
    });
  });
}
