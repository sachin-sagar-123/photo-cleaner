import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_providers.dart';
import '../../../../services/ai_service.dart';
import '../../data/ai_repository.dart';

/// Raw AI service — kept for screens that use it directly.
final aiServiceProvider = Provider((_) => AIService());

/// Cached AI repository with Result<T> error handling.
final aiRepositoryProvider = Provider((ref) =>
    AIRepository(
      ref.read(aiServiceProvider),
      ref.read(memoryCacheProvider),
    ));
