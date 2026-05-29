import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../domain/my_list_repository.dart';
import 'mock_my_list_repository.dart';
import 'remote/my_list_remote_data_source.dart';
import 'remote_my_list_repository.dart';

/// My list remote skeleton 开关。
///
/// 默认必须为 false，避免 API 骨架影响当前已验收的 mock UI。真实接口联调时可通过
/// dart-define 或测试 override 启用。
final useRemoteMyListApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().myList;
});

final myListRepositoryProvider = Provider<MyListRepository>((ref) {
  if (ref.watch(useRemoteMyListApiProvider)) {
    return RemoteMyListRepository(
      remoteDataSource: MyListRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return  MockMyListRepository();
});
