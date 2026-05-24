import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

/// Singleton analytics service.
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
