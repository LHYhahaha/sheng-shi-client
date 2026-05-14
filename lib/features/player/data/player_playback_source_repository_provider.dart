import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_source.dart';
import 'file_player_playback_cache_manager.dart';
import 'mock_player_playback_source_repository.dart';

final playerPlaybackCacheManagerProvider = Provider<PlayerPlaybackCacheManager>(
  (ref) {
    return FilePlayerPlaybackCacheManager(
      cacheDirectory: Directory(
        '${Directory.systemTemp.path}/drama_player_cache',
      ),
    );
  },
);

final playerPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      return MockPlayerPlaybackSourceRepository(
        cacheManager: ref.watch(playerPlaybackCacheManagerProvider),
      );
    });
