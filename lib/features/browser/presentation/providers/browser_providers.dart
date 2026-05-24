import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../models/photo_asset.dart';
import '../../data/browser_dao.dart';
import '../../data/browser_repository.dart';

final browserDaoProvider = Provider((ref) =>
    BrowserDao(ref.read(appDatabaseProvider)));

final browserRepositoryProvider = Provider((ref) =>
    BrowserRepository(
      ref.read(browserDaoProvider),
      ref.read(memoryCacheProvider),
    ));

final unreviewedPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final repo = ref.read(browserRepositoryProvider);
  final result = await repo.getUnreviewedPhotos();
  return result.data;
});
