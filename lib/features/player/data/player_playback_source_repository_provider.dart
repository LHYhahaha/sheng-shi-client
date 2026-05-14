import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_source.dart';
import 'mock_player_playback_source_repository.dart';

final playerPlaybackPreloadManagerProvider =
    Provider<PlayerPlaybackPreloadManager>((ref) {
      return MockPlayerPlaybackPreloadManager();
    });

final playerPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerPlaybackPreloadManagerProvider),
      );
    });
