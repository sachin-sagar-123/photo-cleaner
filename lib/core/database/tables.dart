/// Table and column name constants — single source of truth.
class Tables {
  static const photos = 'photo_assets';
  static const vault = 'vault_documents';
  static const vaultFts = 'vault_fts';
}

class PhotoColumns {
  static const id = 'id';
  static const path = 'path';
  static const name = 'name';
  static const sizeBytes = 'size_bytes';
  static const createdAt = 'created_at';
  static const category = 'category';
  static const issues = 'issues';
  static const suggestedName = 'suggested_name';
  static const isBackedUp = 'is_backed_up';
  static const pHash = 'p_hash';
  static const dHash = 'd_hash';
  static const driveFileId = 'drive_file_id';
  static const driveMd5 = 'drive_md5';
  static const isDriveOnly = 'is_drive_only';
  static const isReviewed = 'is_reviewed';
  static const isImportant = 'is_important';
}

class VaultColumns {
  static const id = 'id';
  static const title = 'title';
  static const imagePath = 'image_path';
  static const type = 'type';
  static const addedAt = 'added_at';
  static const notes = 'notes';
  static const tags = 'tags';
}
