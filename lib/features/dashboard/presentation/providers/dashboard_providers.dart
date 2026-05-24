import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../models/models.dart';
import '../../data/dashboard_dao.dart';
import '../../data/dashboard_repository.dart';

// ── DAO + Repository ──────────────────────────────────────────────────────

final dashboardDaoProvider = Provider((ref) =>
    DashboardDao(ref.read(appDatabaseProvider)));

final dashboardRepositoryProvider = Provider((ref) =>
    DashboardRepository(
      ref.read(dashboardDaoProvider),
      ref.read(memoryCacheProvider),
    ));

// ── Providers (via cached repository with Result<T>) ──────────────────────

final unreviewedCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  final result = await repo.getUnreviewedCount();
  return result.data;
});

final photosCountByCategoryProvider =
    FutureProvider.family<int, PhotoCategory>((ref, cat) async {
  final repo = ref.read(dashboardRepositoryProvider);
  final result = await repo.getCategoryCount(cat);
  return result.data;
});

final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  final result = await repo.getStorageStats();
  return result.data;
});
