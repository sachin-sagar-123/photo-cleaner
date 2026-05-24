import 'dart:developer' as dev;

import 'analytics_event.dart';
import 'perf_tracker.dart';

/// Backend-agnostic analytics service.
///
/// Currently logs to `dart:developer` for debug builds. Swap in
/// Firebase Analytics, Mixpanel, or any other backend by adding
/// an [AnalyticsBackend] implementation.
class AnalyticsService {
  final List<AnalyticsBackend> _backends;

  AnalyticsService({List<AnalyticsBackend>? backends})
      : _backends = backends ?? [DebugLogBackend()];

  /// Track an event.
  void track(AnalyticsEvent event) {
    for (final backend in _backends) {
      backend.track(event);
    }
  }

  /// Start a performance trace. Returns a [PerfTrace] that must be stopped.
  PerfTrace startTrace(String name) {
    return PerfTrace(name);
  }

  /// Track a timed operation. Automatically records duration.
  Future<T> trackTimed<T>(String name, Future<T> Function() operation) async {
    final trace = startTrace(name);
    try {
      final result = await operation();
      trace.stop();
      track(AnalyticsEvent(
        name: 'perf_trace',
        properties: {
          'trace_name': name,
          'duration_ms': trace.durationMs,
        },
      ));
      return result;
    } catch (e) {
      trace.stop();
      track(AnalyticsEvent(
        name: 'perf_trace_error',
        properties: {
          'trace_name': name,
          'duration_ms': trace.durationMs,
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }

  /// Set user properties (e.g., photo count, device model).
  void setUserProperty(String key, String value) {
    for (final backend in _backends) {
      backend.setUserProperty(key, value);
    }
  }
}

/// Interface for analytics backends.
abstract class AnalyticsBackend {
  void track(AnalyticsEvent event);
  void setUserProperty(String key, String value);
}

/// Debug backend that logs to dart:developer.
class DebugLogBackend implements AnalyticsBackend {
  @override
  void track(AnalyticsEvent event) {
    dev.log(
      '${event.name} ${event.properties ?? {}}',
      name: 'Analytics',
      time: event.timestamp,
    );
  }

  @override
  void setUserProperty(String key, String value) {
    dev.log('UserProperty: $key = $value', name: 'Analytics');
  }
}
