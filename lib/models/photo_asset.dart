import 'package:photo_manager/photo_manager.dart';

/// Photo categories — indices 0-5 are legacy (stored in existing DBs).
/// Indices 6-14 are new AI-powered categories added in v5 migration.
/// NEVER reorder existing values — the integer index is persisted in SQLite.
enum PhotoCategory {
  documents,    // 0
  screenshots,  // 1
  food,         // 2
  people,       // 3
  nature,       // 4
  other,        // 5
  // ── Extended categories (v5+) ──
  selfie,       // 6
  animal,       // 7
  architecture, // 8
  meme,         // 9
  art,          // 10
  travel,       // 11
  sport,        // 12
  vehicle,      // 13
  night,        // 14
}

enum QualityIssue { blurry, closedEyes, lowLight, duplicate, junk }

/// Metadata and display helpers for PhotoCategory.
extension PhotoCategoryX on PhotoCategory {
  String get displayName => switch (this) {
    PhotoCategory.documents => 'Documents',
    PhotoCategory.screenshots => 'Screenshots',
    PhotoCategory.food => 'Food',
    PhotoCategory.people => 'People',
    PhotoCategory.nature => 'Nature',
    PhotoCategory.other => 'Other',
    PhotoCategory.selfie => 'Selfie',
    PhotoCategory.animal => 'Animal',
    PhotoCategory.architecture => 'Architecture',
    PhotoCategory.meme => 'Meme',
    PhotoCategory.art => 'Art',
    PhotoCategory.travel => 'Travel',
    PhotoCategory.sport => 'Sport',
    PhotoCategory.vehicle => 'Vehicle',
    PhotoCategory.night => 'Night',
  };

  String get emoji => switch (this) {
    PhotoCategory.documents => '📄',
    PhotoCategory.screenshots => '📱',
    PhotoCategory.food => '🍕',
    PhotoCategory.people => '👥',
    PhotoCategory.nature => '🌿',
    PhotoCategory.other => '📷',
    PhotoCategory.selfie => '🤳',
    PhotoCategory.animal => '🐾',
    PhotoCategory.architecture => '🏛️',
    PhotoCategory.meme => '😂',
    PhotoCategory.art => '🎨',
    PhotoCategory.travel => '✈️',
    PhotoCategory.sport => '⚽',
    PhotoCategory.vehicle => '🚗',
    PhotoCategory.night => '🌙',
  };

  /// Parse from AI response text (case-insensitive).
  static PhotoCategory fromName(String name) {
    final lower = name.trim().toLowerCase();
    // Map AI names to PhotoCategory values
    return switch (lower) {
      'document' || 'documents' => PhotoCategory.documents,
      'screenshot' || 'screenshots' => PhotoCategory.screenshots,
      'food' => PhotoCategory.food,
      'people' => PhotoCategory.people,
      'selfie' => PhotoCategory.selfie,
      'nature' => PhotoCategory.nature,
      'animal' => PhotoCategory.animal,
      'architecture' => PhotoCategory.architecture,
      'meme' => PhotoCategory.meme,
      'art' => PhotoCategory.art,
      'travel' => PhotoCategory.travel,
      'sport' => PhotoCategory.sport,
      'vehicle' => PhotoCategory.vehicle,
      'night' => PhotoCategory.night,
      _ => PhotoCategory.other,
    };
  }
}

/// Represents a photo that exists locally, on Drive, or both.
class PhotoAsset {
  final String id;
  final String path;         // empty string if Drive-only
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final PhotoCategory category;      // local heuristic classification
  final PhotoCategory? aiCategory;   // AI vision classification (overrides local)
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

  // Review state — user marked this photo as OK, skip in future scans
  final bool isReviewed;

  // Important flag — user rescued this photo from junk/blurry
  final bool isImportant;

  const PhotoAsset({
    required this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    this.category = PhotoCategory.other,
    this.aiCategory,
    this.issues = const [],
    this.suggestedName,
    this.isBackedUp = false,
    this.pHash,
    this.dHash,
    this.entity,
    this.driveFileId,
    this.driveMd5,
    this.isDriveOnly = false,
    this.isReviewed = false,
    this.isImportant = false,
  });

  /// The category to display — AI classification takes priority over local heuristics.
  PhotoCategory get effectiveCategory => aiCategory ?? category;

  /// Whether this photo has been categorized by AI.
  bool get hasAICategory => aiCategory != null;

  bool get hasIssues => issues.isNotEmpty;
  bool get isDuplicate => issues.contains(QualityIssue.duplicate);
  bool get isBlurry => issues.contains(QualityIssue.blurry);
  bool get isJunk => issues.contains(QualityIssue.junk);
  double get sizeMB => sizeBytes / (1024 * 1024);
  bool get isLocal => path.isNotEmpty;

  PhotoAsset copyWith({
    String? path,
    PhotoCategory? category,
    Object? aiCategory = _sentinel,
    List<QualityIssue>? issues,
    String? suggestedName,
    bool? isBackedUp,
    String? pHash,
    String? dHash,
    String? driveFileId,
    String? driveMd5,
    bool? isDriveOnly,
    bool? isReviewed,
    bool? isImportant,
  }) {
    return PhotoAsset(
      id: id,
      path: path ?? this.path,
      name: name,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      category: category ?? this.category,
      aiCategory: aiCategory == _sentinel
          ? this.aiCategory
          : aiCategory as PhotoCategory?,
      issues: issues ?? this.issues,
      suggestedName: suggestedName ?? this.suggestedName,
      isBackedUp: isBackedUp ?? this.isBackedUp,
      pHash: pHash ?? this.pHash,
      dHash: dHash ?? this.dHash,
      entity: entity,
      driveFileId: driveFileId ?? this.driveFileId,
      driveMd5: driveMd5 ?? this.driveMd5,
      isDriveOnly: isDriveOnly ?? this.isDriveOnly,
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
        'category': category.index,
        'ai_category': aiCategory?.name,
        'issues': issues.map((e) => e.index).join(','),
        'suggested_name': suggestedName,
        'is_backed_up': isBackedUp ? 1 : 0,
        'p_hash': pHash,
        'd_hash': dHash,
        'drive_file_id': driveFileId,
        'drive_md5': driveMd5,
        'is_drive_only': isDriveOnly ? 1 : 0,
        'is_reviewed': isReviewed ? 1 : 0,
        'is_important': isImportant ? 1 : 0,
      };

  factory PhotoAsset.fromMap(Map<String, dynamic> map) {
    final aiCatName = map['ai_category'] as String?;
    return PhotoAsset(
      id: map['id'] as String,
      path: map['path'] as String,
      name: map['name'] as String,
      sizeBytes: map['size_bytes'] as int,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      category: PhotoCategory.values[map['category'] as int],
      aiCategory: aiCatName != null && aiCatName.isNotEmpty
          ? PhotoCategoryX.fromName(aiCatName)
          : null,
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
      isReviewed: ((map['is_reviewed'] as int?) ?? 0) == 1,
      isImportant: ((map['is_important'] as int?) ?? 0) == 1,
    );
  }
}

/// Sentinel for copyWith to distinguish "not passed" from "explicitly null".
const _sentinel = Object();
