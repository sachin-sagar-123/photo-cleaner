import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'database_service.dart';

/// Handles marking photos as important: removes issue flags, moves the
/// physical file to a dedicated "PhotoCleaner Important" folder, and
/// updates the DB path.
class ImportantService {
  final _db = DatabaseService();

  /// Directory name on device storage for important photos.
  static const _folderName = 'PhotoCleaner Important';

  /// Get or create the Important folder on device storage.
  Future<Directory> _getImportantDir() async {
    // Use DCIM as parent — standard location visible in gallery apps
    final dcim = Directory('/storage/emulated/0/DCIM/$_folderName');
    if (!await dcim.exists()) {
      await dcim.create(recursive: true);
    }
    // Create a .nomedia-free folder so gallery apps index these photos
    return dcim;
  }

  /// Mark a single photo as important:
  /// 1. Remove junk/blurry issue flags
  /// 2. Copy file to Important folder (preserve original)
  /// 3. Update DB with new path and is_important=1
  Future<String?> markAsImportant(PhotoAsset photo) async {
    // Remove issue flags and set is_important in DB
    for (final issue in [QualityIssue.junk, QualityIssue.blurry]) {
      if (photo.issues.contains(issue)) {
        await _db.removeIssue(photo.id, issue);
      }
    }
    if (!photo.issues.contains(QualityIssue.junk) &&
        !photo.issues.contains(QualityIssue.blurry)) {
      await _db.markImportant(photo.id);
    }

    // Move file to Important folder
    if (photo.path.isEmpty) return null;
    final sourceFile = File(photo.path);
    if (!await sourceFile.exists()) return null;

    try {
      final importantDir = await _getImportantDir();
      final fileName = p.basename(photo.path);
      var destPath = p.join(importantDir.path, fileName);

      // Handle name collisions
      if (await File(destPath).exists()) {
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        destPath = p.join(
            importantDir.path, '${nameWithoutExt}_$timestamp$ext');
      }

      // Copy (not move) — preserve original location for gallery apps
      await sourceFile.copy(destPath);

      // Update DB path to the new location
      await _db.updatePhotoPath(photo.id, destPath);

      return destPath;
    } catch (_) {
      // File move failed — photo is still marked important in DB
      return null;
    }
  }

  /// Mark multiple photos as important.
  Future<int> markMultipleAsImportant(List<PhotoAsset> photos) async {
    int moved = 0;
    for (final photo in photos) {
      final result = await markAsImportant(photo);
      if (result != null) moved++;
    }
    return moved;
  }
}
