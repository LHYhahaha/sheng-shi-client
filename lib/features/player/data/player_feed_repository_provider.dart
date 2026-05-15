import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_feed.dart';
import 'mock_player_feed_repository.dart';
import 'player_content_repository_provider.dart';

final playerFeedRepositoryProvider = Provider<PlayerFeedRepository>((ref) {
  // 播放 feed 数据统一注入，保证 For You 和单剧测试可以替换同一入口。页面不要直接
  // new mock repository，否则 sessionKey 隔离和启动 timing 会难以验证。
  return MockPlayerFeedRepository(
    contentRepository: ref.watch(playerContentRepositoryProvider),
  );
});
