import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_progress.dart';
import 'mock_playback_progress_repository.dart';

final playbackProgressRepositoryProvider = Provider<PlaybackProgressRepository>(
  (ref) {
    // 进度仓库保持 provider 注入，便于把当前内存实现替换成本地存储或服务端同步。
    // 播放器控制器只关心接口，不直接知道存储方式。
    return InMemoryPlaybackProgressRepository();
  },
);
