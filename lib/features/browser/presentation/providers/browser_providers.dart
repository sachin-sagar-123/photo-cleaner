import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../models/photo_asset.dart';
import '../../data/browser_dao.dart';

final browserDaoProvider = Provider((ref) =>
    BrowserDao(ref.read(appDatabaseProvider)));

final unreviewedPhotosProvider = FutureProvider<List<PhotoAsset>>((ref) async {
  final dao = ref.read(browserDaoProvider);
  return dao.getUnreviewedPhotos();
});
