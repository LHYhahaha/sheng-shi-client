import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/player_feed.dart';
import 'player_remote_data_source_provider.dart';
import 'remote/player_remote_data_source.dart';
import 'remote_player_feed_repository.dart';

final playerFeedRepositoryProvider = Provider<PlayerFeedRepository>((ref) {
  return RemotePlayerFeedRepository(
    remoteDataSource: PlayerRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
    dramaDetailCache: ref.watch(playerDramaDetailCacheProvider),
  );
});
