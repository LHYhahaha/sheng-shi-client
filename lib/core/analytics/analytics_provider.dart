import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_info_store.dart';
import '../channel/channel_config_service.dart';
import '../../features/entitlement/application/entitlement_controller.dart';
import '../runtime/api_lang_provider.dart';
import '../runtime/api_platform_provider.dart';
import '../runtime/api_region_code_provider.dart';
import '../runtime/app_version_provider.dart';
import '../network/api_client_provider.dart';
import 'analytics_context.dart';
import 'analytics_page_context.dart';
import 'analytics_service.dart';

/// 自动注入埋点公共参数的运行时上下文。
///
/// `session_id` 与 `app_session_id` 已按当前需求移除；页面和来源字段将由后续
/// 路由/深链追踪模块提供。
final analyticsContextProvider = Provider<AnalyticsContext>((ref) {
  final userInfo = ref.watch(userInfoStoreProvider);
  final entitlement = ref.watch(entitlementControllerProvider);
  final channel = ref.watch(channelConfigServiceProvider).cachedConfig;
  final page = ref.watch(analyticsPageContextProvider);

  return AnalyticsContext(
    platform: ref.watch(apiPlatformProvider),
    appVersion: ref.watch(apiAppVersionProvider),
    language: ref.watch(apiLangProvider),
    // 埋点 user_id 使用服务端业务用户 ID（int64 字符串），不使用展示用 showId。
    // 权益接口完成刷新前，回退到 /api/user/get 已保存的同一字段。
    userId: entitlement.userId ?? userInfo.userId,
    channelId: channel?.channelFlag,
    merchantId: channel?.merchantId,
    regionCode: ref.watch(apiRegionCodeProvider),
    pageName: page.currentPage,
    previousPage: page.previousPage,
  );
});

/// 后端埋点上传队列：启动恢复未发送事件，网络恢复后立即补发。
final analyticsUploadSinkProvider = Provider<AnalyticsBatchUploadEventSink>((
  ref,
) {
  final sink = AnalyticsBatchUploadEventSink(
    apiClient: ref.watch(apiClientProvider),
  );
  unawaited(sink.initialize());
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      unawaited(sink.flush());
    }
  });
  ref.onDispose(subscription.cancel);
  ref.onDispose(sink.dispose);
  return sink;
});

final analyticsEventSinkProvider = Provider<AnalyticsEventSink>((ref) {
  return ref.watch(analyticsUploadSinkProvider);
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  // 不能 watch analyticsContextProvider：page_view 写入当前页面后会使本 Provider
  // 重建，连带销毁 AnalyticsPageTracker，下一次页面切换就丢失 enteredAt，导致所有
  // page_leave 都无法生成。AnalyticsService 必须在整个 App 生命周期保持同一实例，
  // 在事件发生时读取当前公共参数即可。
  final eventSink = ref.watch(analyticsEventSinkProvider);
  final initialContext = ref.read(analyticsContextProvider);
  return AnalyticsService(
    contextReader: () =>
        ref.mounted ? ref.read(analyticsContextProvider) : initialContext,
    eventSink: eventSink,
  );
});
