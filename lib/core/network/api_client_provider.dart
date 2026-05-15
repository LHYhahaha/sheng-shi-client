import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_request_context.dart';

final apiRequestContextProvider = Provider<ApiRequestContext>((ref) {
  // Phase B 先提供稳定 mock/default header。后续接真实 device id、locale、
  // app version 和 token storage 时，只替换这个 provider。
  return ApiRequestContext(
    deviceId: 'mock-device-id',
    lang: 'en',
    platform: defaultApiPlatform(),
    appVersion: '1.0.0',
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  // 统一网络入口。即使当前多数 feature 仍是 mock，也不要让页面直接创建网络客户端；
  // 后续鉴权 header、错误映射和测试替身都依赖这个 provider 边界。
  return ApiClient(requestContext: ref.watch(apiRequestContextProvider));
});
