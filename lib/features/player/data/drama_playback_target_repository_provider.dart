import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/drama_playback_target.dart';
import 'shared_preferences_drama_playback_target_repository.dart';

final dramaPlaybackTargetRepositoryProvider =
    Provider<DramaPlaybackTargetRepository>((ref) {
      return SharedPreferencesDramaPlaybackTargetRepository();
    });
