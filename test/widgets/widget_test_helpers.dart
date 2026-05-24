import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_cleaner/models/models.dart';
import 'package:photo_cleaner/providers/app_providers.dart';
import 'package:photo_cleaner/theme/app_theme.dart';

/// Wraps a widget with ProviderScope + MaterialApp using the app theme.
/// Overrides async providers with immediate stub data so widgets render
/// without needing real platform channels or file system.
Widget testApp(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      storageStatsProvider.overrideWith((_) async => StorageStats.empty),
      photosProvider.overrideWith((_) async => []),
      duplicatesProvider.overrideWith((_) async => []),
      vaultDocumentsProvider.overrideWith((_) async => []),
      drivePhotosProvider.overrideWith((_) async => []),
      driveOnlyPhotosProvider.overrideWith((_) async => []),
      driveDuplicatesProvider.overrideWith((_) async => []),
      driveBlurryProvider.overrideWith((_) async => []),
      driveJunkProvider.overrideWith((_) async => []),
      ...PhotoCategory.values.map(
        (cat) => photosByCategoryProvider(cat).overrideWith((_) async => []),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: child,
    ),
  );
}

/// A stub [StorageStats] with realistic non-zero values.
StorageStats get stubStats => const StorageStats(
      totalBytes: 64 * 1024 * 1024 * 1024,
      usedBytes: 8 * 1024 * 1024 * 1024,
      photoBytes: 4 * 1024 * 1024 * 1024,
      duplicateBytes: 512 * 1024 * 1024,
      junkBytes: 256 * 1024 * 1024,
      backedUpBytes: 1024 * 1024 * 1024,
      totalPhotos: 1240,
      duplicateCount: 87,
      junkCount: 43,
    );

PhotoAsset stubAsset(String id) => PhotoAsset(
      id: id,
      path: '/fake/$id.jpg',
      name: '$id.jpg',
      sizeBytes: 2 * 1024 * 1024,
      createdAt: DateTime(2024, 3, 15),
      category: PhotoCategory.people,
      issues: const [QualityIssue.blurry],
    );
