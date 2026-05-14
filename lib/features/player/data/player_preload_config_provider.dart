import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_preload_config.dart';

final playerPreloadConfigProvider = Provider<PlayerPreloadConfig>((ref) {
  return const PlayerPreloadConfig();
});
