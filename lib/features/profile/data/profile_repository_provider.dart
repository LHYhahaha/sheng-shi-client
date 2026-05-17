import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../domain/profile_repository.dart';
import 'mock_profile_repository.dart';
import 'remote/profile_remote_data_source.dart';
import 'remote_profile_repository.dart';

/// Profile 远程接口开关。
///
/// 默认保持 mock，避免本轮 skeleton 影响已经验收的 Profile UI。后续接真实聚合接口时，
/// 只需要打开 provider/feature flag，不要让页面直接依赖 remote data source。
final useRemoteProfileApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().profile;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (ref.watch(useRemoteProfileApiProvider)) {
    return RemoteProfileRepository(
      remoteDataSource: ProfileRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return const MockProfileRepository();
});
