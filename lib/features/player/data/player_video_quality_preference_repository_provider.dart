import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_video_quality.dart';
import 'player_video_quality_preference_repository.dart';

final playerVideoQualityPreferenceRepositoryProvider =
    Provider<PlayerVideoQualityPreferenceRepository>((ref) {
      return SharedPreferencesPlayerVideoQualityPreferenceRepository();
    });

final playerDefaultVideoQualityIdProvider = Provider<String>((ref) {
  return PlayerVideoQuality.automaticId;
});
