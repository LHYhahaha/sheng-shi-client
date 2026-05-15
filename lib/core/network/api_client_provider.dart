import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_token_store.dart';
import '../device/api_device_context_provider.dart';
import '../locale/app_locale_controller.dart';
import 'api_client.dart';
import 'api_request_context.dart';

final apiRequestContextProvider = Provider<ApiRequestContext>((ref) {
  final locale = ref.watch(appLocaleControllerProvider);
  final token = ref.watch(authTokenStoreProvider);

  // 统一请求上下文。feature 不应该自行拼 Device-Id/Lang/Platform/App-Version 或
  // Authorization；真实 device id、package info、secure token 后续只替换对应 provider。
  return ApiRequestContext(
    deviceId: ref.watch(apiDeviceIdProvider),
    lang: locale.languageCode,
    platform: defaultApiPlatform(),
    appVersion: ref.watch(apiAppVersionProvider),
    accessToken: token.accessToken,
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  // 统一网络入口。即使当前多数 feature 仍是 mock，也不要让页面直接创建网络客户端；
  // 后续鉴权 header、错误映射和测试替身都依赖这个 provider 边界。
  return ApiClient(requestContext: ref.watch(apiRequestContextProvider));
});
