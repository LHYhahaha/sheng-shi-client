import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/for_you_player_handoff.dart';

final forYouPlaybackProgressControllerProvider =
    NotifierProvider<
      ForYouPlaybackProgressController,
      Map<String, ForYouPlaybackSnapshot>
    >(ForYouPlaybackProgressController.new);

/// 按 dramaId 保存 For You 最新播放集数和位置。
///
/// 推荐流重新请求可能改变顺序，因此恢复不能依赖列表 index。该缓存仅负责当前进程内
/// 页面存活期间的即时同步；进程重启后的恢复仍由服务端观看记录负责。
class ForYouPlaybackProgressController
    extends Notifier<Map<String, ForYouPlaybackSnapshot>> {
  @override
  Map<String, ForYouPlaybackSnapshot> build() => const {};

  void save(ForYouPlaybackSnapshot snapshot) {
    final previous = state[snapshot.dramaId];
    if (previous != null && previous.updatedAt.isAfter(snapshot.updatedAt)) {
      return;
    }
    state = Map<String, ForYouPlaybackSnapshot>.unmodifiable({
      ...state,
      snapshot.dramaId: snapshot,
    });
  }

  ForYouPlaybackSnapshot? snapshotFor(String dramaId) => state[dramaId];
}
