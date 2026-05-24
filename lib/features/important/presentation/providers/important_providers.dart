import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../models/photo_asset.dart';
import '../../../../services/important_service.dart';
import '../../data/important_dao.dart';

final importantDaoProvider = Provider((ref) =>
    ImportantDao(ref.read(appDatabaseProvider)));

final importantServiceProvider = Provider((_) => ImportantService());

final importantPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(importantDaoProvider);
  return dao.getImportantPhotos();
});

final importantCountProvider = FutureProvider<int>((ref) async {
  final dao = ref.read(importantDaoProvider);
  return dao.getImportantCount();
});
