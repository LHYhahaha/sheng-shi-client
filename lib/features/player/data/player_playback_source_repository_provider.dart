import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_source.dart';
import 'mock_player_playback_source_repository.dart';

final playerPlaybackCacheManagerProvider = Provider<PlayerPlaybackCacheManager>(
  (ref) {
    return MockPlayerPlaybackCacheManager();
  },
);

final playerPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      return MockPlayerPlaybackSourceRepository(
        cacheManager: ref.watch(playerPlaybackCacheManagerProvider),
      );
    });
