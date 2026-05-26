import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import 'database_service.dart';

/// Handles marking photos as important: removes issue flags, moves the
/// physical file to a dedicated "PhotoCleaner Important" folder.
class ImportantService {
  final _db = DatabaseService();

  static const _folderName = 'PhotoCleaner Important';

  Future<Directory> _getImportantDir() async {
    final dcim = Directory('/storage/emulated/0/DCIM/$_folderName');
    if (!await dcim.exists()) {
      await dcim.create(recursive: true);
    }
    return dcim;
  }

  /// Mark a single photo as important:
  /// 1. Remove blurry issue flag (false positive override)
  /// 2. Copy file to Important folder
  /// 3. Update DB
  Future<String?> markAsImportant(PhotoAsset photo) async {
    if (photo.issues.contains(QualityIssue.blurry)) {
      await _db.removeIssue(photo.id, QualityIssue.blurry);
    } else {
      await _db.markImportant(photo.id);
    }

    if (photo.path.isEmpty) return null;
    final sourceFile = File(photo.path);
    if (!await sourceFile.exists()) return null;

    try {
      final importantDir = await _getImportantDir();
      final fileName = p.basename(photo.path);
      var destPath = p.join(importantDir.path, fileName);

      if (await File(destPath).exists()) {
        final nameWithoutExt = p.basenameWithoutExtension(fileName);
        final ext = p.extension(fileName);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        destPath = p.join(importantDir.path, '${nameWithoutExt}_$timestamp$ext');
      }

      await sourceFile.copy(destPath);
      await _db.updatePhotoPath(photo.id, destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  Future<int> markMultipleAsImportant(List<PhotoAsset> photos) async {
    int moved = 0;
    for (final photo in photos) {
      final result = await markAsImportant(photo);
      if (result != null) moved++;
    }
    return moved;
  }
}
