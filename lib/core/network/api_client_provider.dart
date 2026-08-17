import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/api_session_auth_handler.dart';
import '../account/account_ban_controller.dart';
import '../auth/auth_token_store.dart';
import '../channel/channel_config_service.dart';
import '../runtime/api_lang_provider.dart';
import '../runtime/api_platform_provider.dart';
import '../runtime/api_region_code_provider.dart';
import '../runtime/app_version_provider.dart';
import '../runtime/install_id_provider.dart';
import 'api_client.dart';
import 'api_request_context.dart';
import 'system_proxy_config.dart';
import 'test_network_config.dart';

final channelConfigProvider = FutureProvider<ChannelConfig>((ref) async {
  final service = ref.watch(channelConfigServiceProvider);
  return service.getChannelConfig();
});

final channelConfigInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(channelConfigServiceProvider);
  await service.getChannelConfig();
});

final apiRequestContextProvider = Provider<ApiRequestContext>((ref) {
  final token = ref.watch(authTokenStoreProvider);
  final installId = ref.watch(installIdProvider);

  return ApiRequestContext(
    deviceId: installId.when(
      data: (value) => value,
      loading: () => _installIdLoadingFallback,
      error: (_, _) => _installIdLoadingFallback,
    ),
    lang: ref.watch(apiLangProvider),
    platform: ref.watch(apiPlatformProvider),
    appVersion: ref.watch(apiAppVersionProvider),
    regionCode: ref.watch(apiRegionCodeProvider),
    accessToken: token.accessToken,
    refreshToken: token.refreshToken,
    accessTokenExpiresAt: token.expiresAt,
    refreshTokenExpiresAt: token.refreshExpiresAt,
    sessionId: token.subjectId,
    guestId: token.guestId,
  );
});

const _installIdLoadingFallback = 'install-id-pending';

/// API client 是跨页面的基础设施。不能 autoDispose：页面退出后，已发出的 Dio
/// 请求仍可能在拦截器阶段补齐 headers；若此时 Provider 已销毁，再调用 `ref.read`
/// 会直接抛出未捕获异常。
final apiClientProvider = Provider<ApiClient>((ref) {
  final testNetworkConfig = ref.watch(testNetworkConfigProvider);
  final options = ApiClient.defaultOptions
    ..baseUrl = testNetworkConfig.apiBaseUrl;
  final dio = Dio(options);
  configureDioWithProxy(dio, testNetworkConfig.proxy);
  final channelConfigService = ref.read(channelConfigServiceProvider);

  // 正常运行时必须同步读取最新上下文：设备登录刚保存 token 后，紧接着的用户
  // 信息/首页请求就需要带上新 token，不能等 Provider listen 的异步传播。Provider
  // 真正销毁后，Dio 仍可能完成已排队的拦截器，此时只回退到最后一次安全快照，避免
  // 对已销毁 Ref 调用 read。
  var requestContext = ref.read(apiRequestContextProvider);
  final tokenStore = ref.read(authTokenStoreProvider.notifier);
  var isDisposed = false;
  ref.onDispose(() {
    isDisposed = true;
  });

  final apiClient = ApiClient(
    dio: dio,
    requestContextReader: () {
      if (!isDisposed) {
        requestContext = ref.read(apiRequestContextProvider);
      }
      return requestContext;
    },
    // Repository 可能仍持有一个因 provider 刷新而脱离容器的 ApiClient。鉴权
    // 不能依赖它缓存的 ApiRequestContext；设备登录刚写入 token 后，后续受保护
    // 请求与首页请求必须直接读取 TokenStore 的当前快照。
    accessTokenReader: () => tokenStore.snapshot.accessToken,
    channelHeadersReader: () async {
      final channelConfig = await channelConfigService.getChannelConfig();
      return channelConfig.hasConfig
          ? channelConfig.toHeaders()
          : const <String, String>{};
    },
    sessionAuthHandler: null,
    onBusinessError: (error) {
      if (isDisposed) return;
      ref
          .read(accountBanControllerProvider.notifier)
          .reportBusinessCode(error.businessCode);
    },
  );

  final sessionAuthHandler = ref.watch(
    apiSessionAuthHandlerProvider(apiClient),
  );
  apiClient.setSessionAuthHandler(sessionAuthHandler);

  return apiClient;
});
