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
import 'system_proxy_config.dart';

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
    accessToken: token.accessToken,
    refreshToken: token.refreshToken,
    accessTokenExpiresAt: token.expiresAt,
    refreshTokenExpiresAt: token.refreshExpiresAt,
    sessionId: token.subjectId,
    guestId: token.guestId,
  );
});

const _installIdLoadingFallback = 'install-id-pending';

final apiClientProvider = Provider.autoDispose<ApiClient>((ref) {
  final dio = Dio(ApiClient.defaultOptions);
  configureDioWithSystemProxy(dio);

  final apiClient = ApiClient(
    dio: dio,
    requestContextReader: () => ref.read(apiRequestContextProvider),
    sessionAuthHandler: null,
  );

  final sessionAuthHandler = ref.watch(
    apiSessionAuthHandlerProvider(apiClient),
  );
  apiClient.setSessionAuthHandler(sessionAuthHandler);

  return apiClient;
});
