/// Typed analytics events for the app.
///
/// Each event has a name and optional properties map. Events are
/// backend-agnostic — the [AnalyticsService] decides where to send them
/// (Firebase, Mixpanel, local log, etc.).
class AnalyticsEvent {
  final String name;
  final Map<String, Object>? properties;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    this.properties,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'AnalyticsEvent($name, $properties)';

  // -- Scan events --

  static AnalyticsEvent scanStarted({required int photoCount}) =>
      AnalyticsEvent(name: 'scan_started', properties: {'photo_count': photoCount});

  static AnalyticsEvent scanCompleted({
    required int photoCount,
    required int issuesFound,
    required Duration duration,
  }) =>
      AnalyticsEvent(name: 'scan_completed', properties: {
        'photo_count': photoCount,
        'issues_found': issuesFound,
        'duration_ms': duration.inMilliseconds,
      });

  // -- Cleanup events --

  static AnalyticsEvent photosDeleted({required int count, required double mbFreed}) =>
      AnalyticsEvent(name: 'photos_deleted', properties: {
        'count': count,
        'mb_freed': mbFreed,
      });

  static AnalyticsEvent photosCompressed({
    required int count,
    required double mbSaved,
    required String mode,
  }) =>
      AnalyticsEvent(name: 'photos_compressed', properties: {
        'count': count,
        'mb_saved': mbSaved,
        'mode': mode,
      });

  // -- Browser events --

  static AnalyticsEvent photoReviewed({required String action}) =>
      AnalyticsEvent(name: 'photo_reviewed', properties: {'action': action});

  static AnalyticsEvent batchReviewed({required int count}) =>
      AnalyticsEvent(name: 'batch_reviewed', properties: {'count': count});

  // -- Editor events --

  static AnalyticsEvent photoEdited({required List<String> tools}) =>
      AnalyticsEvent(name: 'photo_edited', properties: {'tools': tools.join(',')});

  static AnalyticsEvent collageCreated({required int photoCount, required String template}) =>
      AnalyticsEvent(name: 'collage_created', properties: {
        'photo_count': photoCount,
        'template': template,
      });

  // -- AI events --

  static AnalyticsEvent aiAnalysis({required String type, required String provider}) =>
      AnalyticsEvent(name: 'ai_analysis', properties: {
        'type': type,
        'provider': provider,
      });

  static AnalyticsEvent aiChat({required String provider}) =>
      AnalyticsEvent(name: 'ai_chat', properties: {'provider': provider});

  // -- Navigation events --

  static AnalyticsEvent screenView({required String screen}) =>
      AnalyticsEvent(name: 'screen_view', properties: {'screen': screen});

  // -- Important events --

  static AnalyticsEvent markedImportant({required int count}) =>
      AnalyticsEvent(name: 'marked_important', properties: {'count': count});

  // -- Drive events --

  static AnalyticsEvent driveSyncStarted() =>
      AnalyticsEvent(name: 'drive_sync_started');

  static AnalyticsEvent driveSyncCompleted({required int photosFound}) =>
      AnalyticsEvent(name: 'drive_sync_completed', properties: {
        'photos_found': photosFound,
      });
}
