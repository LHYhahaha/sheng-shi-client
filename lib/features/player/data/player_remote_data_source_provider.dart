import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import 'player_drama_detail_cache.dart';
import 'remote/player_remote_data_source.dart';

/// 播放器远程数据源 provider。
final playerRemoteDataSourceProvider = Provider<PlayerRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlayerRemoteDataSource(apiClient: apiClient);
});

final playerDramaDetailCacheProvider = Provider<PlayerDramaDetailCache>((ref) {
  return PlayerDramaDetailCache(
    remoteDataSource: ref.watch(playerRemoteDataSourceProvider),
  );
});
