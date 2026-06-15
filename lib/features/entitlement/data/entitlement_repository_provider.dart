import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../domain/entitlement_repository.dart';
import 'mock_entitlement_repository.dart';
import 'remote/entitlement_remote_data_source.dart';
import 'remote_entitlement_repository.dart';

final useRemoteEntitlementApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().entitlement;
});

/// Entitlement repository provider。
///
/// 当前默认使用 mock repository。真实 API 接入时，只替换这里的实现即可；UI、
/// Controller 和 Player 不应该直接 new mock 或远程 repository。
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  if (ref.watch(useRemoteEntitlementApiProvider)) {
    return RemoteEntitlementRepository(
      remoteDataSource: EntitlementRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
      ref: ref,
    );
  }
  return MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOn();
});
