import 'package:photo_manager/photo_manager.dart';

/// Quality issues detected during scan.
enum QualityIssue { blurry, duplicate }

/// Represents a photo on the device.
class PhotoAsset {
  final String id;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final List<QualityIssue> issues;
  final String? pHash;
  final String? dHash;
  final AssetEntity? entity;
  final bool isBackedUp;
  final bool isReviewed;
  final bool isImportant;

  const PhotoAsset({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    this.issues = const [],
    this.pHash,
    this.dHash,
    this.entity,
    this.isBackedUp = false,
    this.isReviewed = false,
    this.isImportant = false,
  });

  bool get hasIssues => issues.isNotEmpty;
  bool get isDuplicate => issues.contains(QualityIssue.duplicate);
  bool get isBlurry => issues.contains(QualityIssue.blurry);
  double get sizeMB => sizeBytes / (1024 * 1024);
  bool get isLocal => path.isNotEmpty;

  PhotoAsset copyWith({
    String? path,
    List<QualityIssue>? issues,
    bool? isBackedUp,
    String? pHash,
    String? dHash,
    bool? isReviewed,
    bool? isImportant,
  }) {
    return PhotoAsset(
      id: id,
      path: path ?? this.path,
      name: name,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      issues: issues ?? this.issues,
      isBackedUp: isBackedUp ?? this.isBackedUp,
      pHash: pHash ?? this.pHash,
      dHash: dHash ?? this.dHash,
      entity: entity,
      isReviewed: isReviewed ?? this.isReviewed,
      isImportant: isImportant ?? this.isImportant,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'name': name,
        'size_bytes': sizeBytes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'category': 5, // legacy column — always 'other'
        'issues': issues.map((e) => e.index).join(','),
        'is_backed_up': isBackedUp ? 1 : 0,
        'p_hash': pHash,
        'd_hash': dHash,
        'is_reviewed': isReviewed ? 1 : 0,
        'is_important': isImportant ? 1 : 0,
      };

  factory PhotoAsset.fromMap(Map<String, dynamic> map) {
    return PhotoAsset(
      id: map['id'] as String,
      path: map['path'] as String,
      name: map['name'] as String,
      sizeBytes: map['size_bytes'] as int,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      issues: _parseIssues(map['issues'] as String?),
      isBackedUp: (map['is_backed_up'] as int) == 1,
      pHash: map['p_hash'] as String?,
      dHash: map['d_hash'] as String?,
      isReviewed: ((map['is_reviewed'] as int?) ?? 0) == 1,
      isImportant: ((map['is_important'] as int?) ?? 0) == 1,
    );
  }

  /// Parse issues from DB, mapping old indices to new enum values.
  /// Old enum: blurry=0, closedEyes=1, lowLight=2, duplicate=3, junk=4
  /// New enum: blurry=0, duplicate=1
  static List<QualityIssue> _parseIssues(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final result = <QualityIssue>[];
    for (final s in raw.split(',')) {
      if (s.isEmpty) continue;
      final idx = int.tryParse(s);
      if (idx == null) continue;
      switch (idx) {
        case 0: result.add(QualityIssue.blurry);
        case 3: result.add(QualityIssue.duplicate);
        // 1 (closedEyes), 2 (lowLight), 4 (junk) — ignored
      }
    }
    return result;
  }
}
