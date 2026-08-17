import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';

/// 自营广告素材点击的埋点参数。
Map<String, Object?> adMaterialClickParameters({
  required String adSessionId,
  required String adMaterialId,
}) {
  return {
    'element_name': 'ad_material',
    'ad_session_id': adSessionId,
    'ad_material_id': adMaterialId,
  };
}

/// Keeps an ad session's start/end analytics one-shot and independent from UI.
class AdUnlockAnalyticsTracker {
  AdUnlockAnalyticsTracker({
    required AnalyticsService analytics,
    required this.adSessionId,
    required this.adMaterialId,
    required this.dramaId,
    required this.episodeId,
  }) : _analytics = analytics;

  final AnalyticsService _analytics;
  final String adSessionId;
  final String adMaterialId;
  final String dramaId;
  final String episodeId;
  bool _didReportStart = false;
  bool _didReportEnd = false;

  Future<void> markMaterialVisible() async {
    if (_didReportStart) return;
    _didReportStart = true;
    await _analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.adViewStart, {
        'ad_session_id': adSessionId,
        'ad_material_id': adMaterialId,
        'drama_id': dramaId,
        'episode_id': episodeId,
      }),
    );
  }

  Future<void> finish({
    required Duration watchedDuration,
    bool materialLoadFailed = false,
    bool sessionInvalid = false,
    bool reachedRequiredWatchTime = false,
  }) async {
    if (_didReportEnd) return;
    _didReportEnd = true;
    final result = materialLoadFailed
        ? 'load_failed'
        : sessionInvalid
        ? 'session_invalid'
        : reachedRequiredWatchTime
        ? 'qualified'
        : 'early_exit';
    await _analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.adViewEnd, {
        'ad_session_id': adSessionId,
        'ad_material_id': adMaterialId,
        'drama_id': dramaId,
        'episode_id': episodeId,
        'ad_view_duration_ms': watchedDuration.inMilliseconds,
        'ad_view_result': result,
      }),
    );
  }
}

/// Deduplicates entry exposures for one player page session.
class AdUnlockEntryExposureTracker {
  AdUnlockEntryExposureTracker({required AnalyticsService analytics})
    : _analytics = analytics;

  final AnalyticsService _analytics;
  final Set<String> _reportedEntryKeys = <String>{};

  Future<void> reportIfVisible({
    required String dramaId,
    required String episodeId,
    required String dramaAccessType,
    required String adMaterialId,
  }) async {
    final key = '$dramaId:$episodeId:$adMaterialId';
    if (!_reportedEntryKeys.add(key)) return;
    await _analytics.track(
      AnalyticsEvent(AnalyticsDefinitions.adUnlockEntryExposure, {
        'drama_id': dramaId,
        'episode_id': episodeId,
        'drama_access_type': dramaAccessType,
        'ad_material_id': adMaterialId,
      }),
    );
  }
}
