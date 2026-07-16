import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/member_points_repository.dart';
import 'remote/member_points_remote_data_source.dart';
import 'remote_member_points_repository.dart';

final memberPointsRepositoryProvider = Provider<MemberPointsRepository>((ref) {
  return RemoteMemberPointsRepository(
    remoteDataSource: MemberPointsRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});
