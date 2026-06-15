import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/api_session_auth_handler.dart';
import '../auth/auth_token_store.dart';
import '../channel/channel_config_service.dart';
import '../runtime/api_lang_provider.dart';
import '../runtime/api_platform_provider.dart';
import '../runtime/app_version_provider.dart';
import '../runtime/install_id_provider.dart';
import 'api_client.dart';
import 'api_request_context.dart';
import 'proxy_config.dart';

/// 渠道配置Provider（异步加载）
final channelConfigProvider = FutureProvider<ChannelConfig>((ref) async {
  final service = ref.watch(channelConfigServiceProvider);
  return service.getChannelConfig();
});

/// 渠道配置初始化Provider
///
/// 在应用启动时调用，确保渠道配置被加载
final channelConfigInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(channelConfigServiceProvider);
  await service.getChannelConfig();
});

final apiRequestContextProvider = Provider<ApiRequestContext>((ref) {
  final token = ref.watch(authTokenStoreProvider);
  final installId = ref.watch(installIdProvider);

  // 统一请求上下文。feature 不应自行拼 Device-Id/Lang/Platform/App-Version 或
  // Authorization；联调时仅替换 runtime provider。
  return ApiRequestContext(
    deviceId: installId.when(
      data: (value) => value,
      loading: () => _installIdLoadingFallback,
      error: (_, _) => _installIdLoadingFallback,
    ),
    lang: ref.watch(apiLangProvider),
    platform: ref.watch(apiPlatformProvider),
    appVersion: ref.watch(apiAppVersionProvider),
    accessToken: token.accessToken,
    refreshToken: token.refreshToken,
    accessTokenExpiresAt: token.expiresAt,
    refreshTokenExpiresAt: token.refreshExpiresAt,
    sessionId: token.subjectId,
    guestId: token.guestId,
  );
});

/// install id 尚未加载完成时的短暂 fallback（首帧）；[installIdProvider] 完成后会重建。
const _installIdLoadingFallback = 'install-id-pending';

/// ApiClient Provider
/// 
/// 使用 autoDispose 确保在代理配置变化时能够重新创建
final apiClientProvider = Provider.autoDispose<ApiClient>((ref) {
  // 监听代理配置变化
  final proxyState = ref.watch(proxyConfigProvider);
  
  // 创建 Dio 实例并配置代理
  final dio = Dio(ApiClient.defaultOptions);
  if (proxyState.isEnabled && proxyState.proxyAddress != null) {
    configureDioProxy(dio, proxyState.proxyAddress);
  }

  // 创建 ApiClient，但先不传 sessionAuthHandler
  final apiClient = ApiClient(
    dio: dio,
    requestContextReader: () => ref.read(apiRequestContextProvider),
    sessionAuthHandler: null,
  );
  
  // 现在创建 sessionAuthHandler，传入已创建的 apiClient
  final sessionAuthHandler = ref.watch(
    apiSessionAuthHandlerProvider(apiClient),
  );
  
  // 更新 ApiClient 的 sessionAuthHandler
  apiClient.setSessionAuthHandler(sessionAuthHandler);
  
  return apiClient;
});

