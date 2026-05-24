enum DocumentType { idCard, passport, license, insurance, receipt, other }

class VaultDocument {
  final String id;
  final String title;
  final String imagePath;
  final DocumentType type;
  final DateTime addedAt;
  final String? notes;
  final List<String> tags;

  const VaultDocument({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.type,
    required this.addedAt,
    this.notes,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'image_path': imagePath,
        'type': type.index,
        'added_at': addedAt.millisecondsSinceEpoch,
        'notes': notes,
        'tags': tags.join(','),
      };

  factory VaultDocument.fromMap(Map<String, dynamic> map) => VaultDocument(
        id: map['id'] as String,
        title: map['title'] as String,
        imagePath: map['image_path'] as String,
        type: DocumentType.values[map['type'] as int],
        addedAt:
            DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
        notes: map['notes'] as String?,
        tags: (map['tags'] as String?)
                ?.split(',')
                .where((s) => s.isNotEmpty)
                .toList() ??
            [],
      );

  VaultDocument copyWith({
    String? title,
    DocumentType? type,
    String? notes,
    List<String>? tags,
  }) =>
      VaultDocument(
        id: id,
        title: title ?? this.title,
        imagePath: imagePath,
        type: type ?? this.type,
        addedAt: addedAt,
        notes: notes ?? this.notes,
        tags: tags ?? this.tags,
      );
}
