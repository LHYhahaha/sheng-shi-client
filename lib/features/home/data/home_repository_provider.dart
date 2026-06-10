import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/channel/channel_config_service.dart';
import '../../../core/network/api_client_provider.dart';
import 'home_repository.dart';
import 'remote/home_remote_data_source.dart';
import 'remote_home_repository.dart';

/// 首页 repository provider。
///
/// 提供首页数据仓库实例，用于获取首页数据。
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return RemoteHomeRepository(
    remoteDataSource: HomeRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
      channelConfigService: ref.watch(channelConfigServiceProvider),
    ),
  );
});
