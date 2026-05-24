import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../models/models.dart';
import '../../data/cleanup_dao.dart';
import '../../data/cleanup_repository.dart';

final cleanupDaoProvider = Provider((ref) =>
    CleanupDao(ref.read(appDatabaseProvider)));

final cleanupRepositoryProvider = Provider((ref) =>
    CleanupRepository(
      ref.read(cleanupDaoProvider),
      ref.read(memoryCacheProvider),
    ));

final junkPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final repo = ref.read(cleanupRepositoryProvider);
  final result = await repo.getJunkPhotos();
  return result.data;
});

final blurryPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final repo = ref.read(cleanupRepositoryProvider);
  final result = await repo.getBlurryPhotos();
  return result.data;
});

final backedUpCleanupProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final repo = ref.read(cleanupRepositoryProvider);
  final result = await repo.getBackedUpPhotos();
  return result.data;
});
