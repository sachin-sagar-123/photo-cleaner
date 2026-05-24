import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../models/models.dart';
import '../../data/cleanup_dao.dart';

final cleanupDaoProvider = Provider((ref) =>
    CleanupDao(ref.read(appDatabaseProvider)));

final junkPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(cleanupDaoProvider);
  return dao.getPhotosByIssue(QualityIssue.junk);
});

final blurryPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(cleanupDaoProvider);
  return dao.getPhotosByIssue(QualityIssue.blurry);
});

final backedUpCleanupProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(cleanupDaoProvider);
  return dao.getBackedUpPhotosForCleanup();
});
