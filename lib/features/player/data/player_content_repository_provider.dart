import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/remote_api_switches.dart';
import '../domain/player_content.dart';
import 'mock_player_content_repository.dart';
import 'remote/player_remote_data_source.dart';
import 'remote_player_content_repository.dart';

final useRemotePlayerApiProvider = Provider<bool>((ref) {
  return RemoteApiSwitches.fromEnvironment().player;
});

final playerContentRepositoryProvider = Provider<PlayerContentRepository>((
  ref,
) {
  // 内容详情统一入口。播放器页面只依赖 repository 接口，后续接真实详情/推荐接口时
  // 不需要改 presentation 层。
  if (ref.watch(useRemotePlayerApiProvider)) {
    return RemotePlayerContentRepository(
      remoteDataSource: PlayerRemoteDataSource(
        apiClient: ref.watch(apiClientProvider),
      ),
    );
  }
  return const MockPlayerContentRepository();
});
