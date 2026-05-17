import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/api_session_auth_handler.dart';
import '../auth/auth_token_store.dart';
import '../runtime/api_lang_provider.dart';
import '../runtime/api_platform_provider.dart';
import '../runtime/app_version_provider.dart';
import '../runtime/install_id_provider.dart';
import 'api_client.dart';
import 'api_request_context.dart';

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
  );
});

/// install id 尚未加载完成时的短暂 fallback（首帧）；[installIdProvider] 完成后会重建。
const _installIdLoadingFallback = 'install-id-pending';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    requestContextReader: () => ref.read(apiRequestContextProvider),
    sessionAuthHandler: ref.watch(apiSessionAuthHandlerProvider),
  );
});
