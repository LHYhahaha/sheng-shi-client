import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_info_store.dart';
import '../channel/channel_config_service.dart';
import '../runtime/api_lang_provider.dart';
import '../runtime/api_platform_provider.dart';
import '../runtime/api_region_code_provider.dart';
import '../runtime/app_version_provider.dart';
import 'analytics_context.dart';
import 'analytics_page_context.dart';
import 'analytics_service.dart';

/// 自动注入埋点公共参数的运行时上下文。
///
/// `session_id` 与 `app_session_id` 已按当前需求移除；页面和来源字段将由后续
/// 路由/深链追踪模块提供。
final analyticsContextProvider = Provider<AnalyticsContext>((ref) {
  final userInfo = ref.watch(userInfoStoreProvider);
  final channel = ref.watch(channelConfigServiceProvider).cachedConfig;
  final page = ref.watch(analyticsPageContextProvider);

  return AnalyticsContext(
    platform: ref.watch(apiPlatformProvider),
    appVersion: ref.watch(apiAppVersionProvider),
    language: ref.watch(apiLangProvider),
    // 埋点表的 user_id 口径是对外展示的 showId，不使用 JWT subject/userId。
    userId: userInfo.showId,
    channelId: channel?.channelFlag,
    merchantId: channel?.merchantId,
    regionCode: ref.watch(apiRegionCodeProvider),
    pageName: page.currentPage,
    previousPage: page.previousPage,
  );
});

/// 后端埋点接口未接入前的进程内缓冲；联调时替换为持久化上传 Sink。
final analyticsEventSinkProvider = Provider<AnalyticsEventSink>((ref) {
  return AnalyticsInMemoryEventSink(logEvents: kDebugMode);
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(
    contextReader: () => ref.read(analyticsContextProvider),
    eventSink: ref.watch(analyticsEventSinkProvider),
  );
});
