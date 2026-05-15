import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/auth_repository.dart';
import 'mock_auth_repository.dart';
import 'remote/auth_remote_data_source.dart';
import 'remote_auth_repository.dart';

final useRemoteAuthApiProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('USE_REMOTE_AUTH_API');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Auth repository 统一注入，后续接设备登录、Google/Facebook SDK 或服务端 token
  // 时不需要改页面。页面不要直接调用平台 SDK。
  if (ref.watch(useRemoteAuthApiProvider)) {
    return RemoteAuthRepository(
      remoteDataSource: AuthRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
      requestContext: ref.watch(apiRequestContextProvider),
    );
  }
  return MockAuthRepository();
});
