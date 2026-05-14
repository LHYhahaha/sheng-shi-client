import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_progress.dart';
import 'mock_playback_progress_repository.dart';

final playbackProgressRepositoryProvider = Provider<PlaybackProgressRepository>(
  (ref) {
    return InMemoryPlaybackProgressRepository();
  },
);
