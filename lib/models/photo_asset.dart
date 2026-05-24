import 'package:photo_manager/photo_manager.dart';

enum PhotoCategory { documents, screenshots, food, people, nature, other }

enum QualityIssue { blurry, closedEyes, lowLight, duplicate, junk }

/// Represents a photo that exists locally, on Drive, or both.
class PhotoAsset {
  final String id;
  final String path;         // empty string if Drive-only
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final PhotoCategory category;
  final List<QualityIssue> issues;
  final String? suggestedName;
  final bool isBackedUp;
  final String? pHash;
  final String? dHash;
  final AssetEntity? entity;

  // Drive-specific fields
  final String? driveFileId;   // Drive API file ID — needed for delete
  final String? driveMd5;      // MD5 checksum from Drive metadata
  final bool isDriveOnly;      // true = exists on Drive but not locally

  const PhotoAsset({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    this.category = PhotoCategory.other,
    this.issues = const [],
    this.suggestedName,
    this.isBackedUp = false,
    this.pHash,
    this.dHash,
    this.entity,
    this.driveFileId,
    this.driveMd5,
    this.isDriveOnly = false,
  });

  bool get hasIssues => issues.isNotEmpty;
  bool get isDuplicate => issues.contains(QualityIssue.duplicate);
  bool get isBlurry => issues.contains(QualityIssue.blurry);
  bool get isJunk => issues.contains(QualityIssue.junk);
  double get sizeMB => sizeBytes / (1024 * 1024);
  bool get isLocal => path.isNotEmpty;

  PhotoAsset copyWith({
    PhotoCategory? category,
    List<QualityIssue>? issues,
    String? suggestedName,
    bool? isBackedUp,
    String? pHash,
    String? dHash,
    String? driveFileId,
    String? driveMd5,
    bool? isDriveOnly,
  }) {
    return PhotoAsset(
      id: id,
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      category: category ?? this.category,
      issues: issues ?? this.issues,
      suggestedName: suggestedName ?? this.suggestedName,
      isBackedUp: isBackedUp ?? this.isBackedUp,
      pHash: pHash ?? this.pHash,
      dHash: dHash ?? this.dHash,
      entity: entity,
      driveFileId: driveFileId ?? this.driveFileId,
      driveMd5: driveMd5 ?? this.driveMd5,
      isDriveOnly: isDriveOnly ?? this.isDriveOnly,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'name': name,
        'size_bytes': sizeBytes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'category': category.index,
        'issues': issues.map((e) => e.index).join(','),
        'suggested_name': suggestedName,
        'is_backed_up': isBackedUp ? 1 : 0,
        'p_hash': pHash,
        'd_hash': dHash,
        'drive_file_id': driveFileId,
        'drive_md5': driveMd5,
        'is_drive_only': isDriveOnly ? 1 : 0,
      };

  factory PhotoAsset.fromMap(Map<String, dynamic> map) => PhotoAsset(
        id: map['id'] as String,
        path: map['path'] as String,
        name: map['name'] as String,
        sizeBytes: map['size_bytes'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        category: PhotoCategory.values[map['category'] as int],
        issues: (map['issues'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .map((s) => QualityIssue.values[int.parse(s)])
                .toList() ??
            [],
        suggestedName: map['suggested_name'] as String?,
        isBackedUp: (map['is_backed_up'] as int) == 1,
        pHash: map['p_hash'] as String?,
        dHash: map['d_hash'] as String?,
        driveFileId: map['drive_file_id'] as String?,
        driveMd5: map['drive_md5'] as String?,
        isDriveOnly: ((map['is_drive_only'] as int?) ?? 0) == 1,
      );
}
