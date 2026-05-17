import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../domain/membership_repository.dart';
import 'mock_membership_repository.dart';
import 'remote/membership_remote_data_source.dart';
import 'remote_membership_repository.dart';

final useRemoteMembershipApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().membership;
});

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  if (ref.watch(useRemoteMembershipApiProvider)) {
    return RemoteMembershipRepository(
      remoteDataSource: MembershipRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return const MockMembershipRepository();
});
