import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_preload_config.dart';

final playerPreloadConfigProvider = Provider<PlayerPreloadConfig>((ref) {
  // 预热策略统一从这里读取，方便后续替换为远程配置。不要在 controller 里硬编码
  // 具体数量，否则 HLS preload 和 session prepare 的 cap 很容易被改散。
  return const PlayerPreloadConfig();
});
