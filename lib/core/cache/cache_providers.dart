import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_entry.dart';

/// Singleton MemoryCache shared across all repositories.
final memoryCacheProvider = Provider<MemoryCache>((ref) {
  return MemoryCache();
});
