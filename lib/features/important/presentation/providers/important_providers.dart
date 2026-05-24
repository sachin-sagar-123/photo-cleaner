import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../models/photo_asset.dart';
import '../../../../services/important_service.dart';
import '../../data/important_dao.dart';
import '../../data/important_repository.dart';

final importantDaoProvider = Provider((ref) =>
    ImportantDao(ref.read(appDatabaseProvider)));

final importantRepositoryProvider = Provider((ref) =>
    ImportantRepository(
      ref.read(importantDaoProvider),
      ref.read(memoryCacheProvider),
    ));

/// Kept for screens that still use the old service directly.
final importantServiceProvider = Provider((_) => ImportantService());

final importantPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final repo = ref.read(importantRepositoryProvider);
  final result = await repo.getImportantPhotos();
  return result.data;
});

final importantCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(importantRepositoryProvider);
  final result = await repo.getImportantCount();
  return result.data;
});
