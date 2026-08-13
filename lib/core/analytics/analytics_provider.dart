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
  // AnalyticsService 可能被 Banner 等延迟 UI 回调短暂持有。不要把 Ref.read 的闭包
  // 交给它：ProviderScope 热重载/重建后，旧 service 再取上下文会访问已 dispose 的
  // ref。watch 让上下文变化时创建新 service，而旧 service 使用创建当时的快照安全
  // 完成已经发起的事件。
  final context = ref.watch(analyticsContextProvider);
  final eventSink = ref.watch(analyticsEventSinkProvider);
  return AnalyticsService(contextReader: () => context, eventSink: eventSink);
});
