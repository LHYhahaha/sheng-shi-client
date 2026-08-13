import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_provider.dart';
import '../../../core/analytics/analytics_service.dart';
import '../data/dto/bottom_tab_response_dto.dart';

/// 动态底部 Tab 的生命周期级曝光去重器。
///
/// 一个 [tabConfigId] 在当前 App 进程中只上报一次。底部导航可能因全屏播放器
/// 暂时移除后重新创建，去重状态不能放在导航 Widget 内。
class DynamicTabExposureTracker {
  DynamicTabExposureTracker({required AnalyticsService analytics})
    : _analytics = analytics;

  final AnalyticsService _analytics;
  final Set<String> _exposedTabConfigIds = <String>{};
  final Set<String> _pendingTabConfigIds = <String>{};

  Future<void> trackVisible(BottomTabDto tab) async {
    final tabConfigId = tab.tabConfigId.trim();
    final replaceTabKey = tab.replaceTab.trim().toLowerCase();
    if (tabConfigId.isEmpty ||
        replaceTabKey.isEmpty ||
        _exposedTabConfigIds.contains(tabConfigId) ||
        !_pendingTabConfigIds.add(tabConfigId)) {
      return;
    }

    try {
      final payload = await _analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.dynamicTabExposure, {
          'tab_config_id': tabConfigId,
          'replace_tab_key': replaceTabKey,
        }),
      );
      if (payload != null) {
        _exposedTabConfigIds.add(tabConfigId);
      }
    } catch (error, stackTrace) {
      // 热重启时旧导航的 post-frame 回调可能持有已经释放的 ProviderScope。
      // 该次曝光无需反复尝试，避免影响界面或重复打印异常。
      _exposedTabConfigIds.add(tabConfigId);
      debugPrint('[Analytics] Dynamic tab exposure skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _pendingTabConfigIds.remove(tabConfigId);
    }
  }
}

/// 与 App 同生命周期的动态 Tab 曝光状态。
final dynamicTabExposureTrackerProvider = Provider<DynamicTabExposureTracker>((
  ref,
) {
  return DynamicTabExposureTracker(
    analytics: ref.watch(analyticsServiceProvider),
  );
});
