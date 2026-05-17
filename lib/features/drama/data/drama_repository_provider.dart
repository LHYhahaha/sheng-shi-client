import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../domain/drama_repository.dart';
import 'mock_drama_repository.dart';
import 'remote/drama_remote_data_source.dart';
import 'remote_drama_repository.dart';

/// Home/Drama 远程接口开关。
///
/// 默认必须为 false：Phase A 只铺 DTO/mapper/remote repository 骨架，不替换已验收的
/// mock 数据链路。需要本地验证远程实现时，优先使用
/// `--dart-define=USE_REMOTE_DRAMA_API=true`。
final useRemoteDramaApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().dramaEnabled;
});

final dramaRepositoryProvider = Provider<DramaRepository>((ref) {
  // 首页数据源统一从 provider 注入，方便 mock/真实接口切换。页面不要直接 new
  // repository，否则 startup preload、分页测试和后续接口替换会分叉。
  if (ref.watch(useRemoteDramaApiProvider)) {
    return RemoteDramaRepository(
      remoteDataSource: DramaRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return const MockDramaRepository();
});
