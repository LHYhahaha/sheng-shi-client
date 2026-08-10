import 'package:flutter/foundation.dart';

import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_entry_source.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_service.dart';

/// 首页接口 Banner 对应的埋点字段。
///
/// 接口接入后，将 banner id、跳转类型和短剧目标映射为该对象；展示图片本身不参与
/// 埋点判断，避免本地资源路径被误当作运营 Banner ID。
class HomeBannerAnalyticsItem {
  const HomeBannerAnalyticsItem({
    required this.bannerId,
    required this.targetType,
    this.targetDramaId,
  });

  final String bannerId;
  final String targetType;
  final String? targetDramaId;

  Map<String, Object?> toEventParameters() => {
    'banner_id': bannerId,
    'banner_target_type': targetType,
    if (targetType == 'drama') 'target_drama_id': targetDramaId,
  };
}

/// Banner 点击且即将进入 App 内目标页时调用。
///
/// 当前首页尚未接入服务端 Banner 点击 UI；后续接入时在实际路由前调用本方法。
void prepareHomeBannerEntrySource(
  AnalyticsEntrySourceController entrySource,
  HomeBannerAnalyticsItem banner,
) {
  final bannerId = banner.bannerId.trim();
  if (bannerId.isEmpty) {
    debugPrint(
      '[Analytics] Entry source data-quality error: banner target is missing banner_id.',
    );
    return;
  }
  entrySource.prepare(type: 'banner', id: bannerId);
}

/// 首页 Banner 曝光去重器。
///
/// 每次进入首页调用 [beginPageSession]；首张和轮播切换到的新 Banner 调用
/// [trackVisible]。同一 Banner 在当前页面周期仅上报一次。
class HomeBannerExposureTracker {
  HomeBannerExposureTracker({required AnalyticsService analytics})
    : _analytics = analytics;

  final AnalyticsService _analytics;
  final Set<String> _exposedBannerIds = <String>{};
  final Set<String> _pendingBannerIds = <String>{};

  void beginPageSession() {
    _exposedBannerIds.clear();
    _pendingBannerIds.clear();
  }

  Future<void> trackVisible(HomeBannerAnalyticsItem banner) async {
    final bannerId = banner.bannerId;
    if (bannerId.isEmpty ||
        _exposedBannerIds.contains(bannerId) ||
        !_pendingBannerIds.add(bannerId)) {
      return;
    }

    try {
      final payload = await _analytics.track(
        AnalyticsEvent(
          AnalyticsDefinitions.homeBannerExposure,
          banner.toEventParameters(),
        ),
      );
      if (payload != null) {
        _exposedBannerIds.add(bannerId);
      }
    } finally {
      _pendingBannerIds.remove(bannerId);
    }
  }
}
