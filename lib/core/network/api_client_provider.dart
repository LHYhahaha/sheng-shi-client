import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  // 统一网络入口。即使当前多数 feature 仍是 mock，也不要让页面直接创建网络客户端；
  // 后续鉴权 header、错误映射和测试替身都依赖这个 provider 边界。
  return ApiClient();
});
