import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../models/models.dart';
import '../../data/dashboard_dao.dart';

// ── DAO ───────────────────────────────────────────────────────────────────

final dashboardDaoProvider = Provider((ref) =>
    DashboardDao(ref.read(appDatabaseProvider)));

// ── Providers ─────────────────────────────────────────────────────────────

final unreviewedCountProvider = FutureProvider<int>((ref) async {
  final dao = ref.read(dashboardDaoProvider);
  return dao.getUnreviewedCount();
});

final photosCountByCategoryProvider =
    FutureProvider.family<int, PhotoCategory>((ref, cat) async {
  final dao = ref.read(dashboardDaoProvider);
  return dao.getPhotosCountByCategory(cat);
});

/// Storage stats via SQL aggregates — 0 bytes heap.
final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final dao = ref.read(dashboardDaoProvider);
  final agg = await dao.getStorageAggregates();

  const totalBytes = 68719476736; // 64 GB

  return StorageStats(
    totalBytes: totalBytes,
    usedBytes: agg['total_bytes']!,
    photoBytes: agg['total_bytes']!,
    duplicateBytes: agg['duplicate_bytes']!,
    junkBytes: agg['junk_bytes']!,
    backedUpBytes: agg['backed_up_bytes']!,
    totalPhotos: agg['total_photos']!,
    duplicateCount: agg['duplicate_count']!,
    junkCount: agg['junk_count']!,
  );
});
