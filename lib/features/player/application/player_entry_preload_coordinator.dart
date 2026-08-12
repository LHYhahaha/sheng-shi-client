import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_startup_preload_controller.dart';

/// 普通播放器入口的统一预取调度。
///
/// For You 有独立的 feed/session 预热，不能走这里；其余入口无论来自首页、搜索、
/// 收藏、会员推荐、弹窗还是深链，都会先经过此处。这样详情 Future 与 HLS 分片预热
/// 只保留一个候选，真实播放发生时再由 PlaybackController 抢占网络优先级。
final playerEntryPreloadCoordinatorProvider =
    NotifierProvider<PlayerEntryPreloadCoordinator, PlayerEntryPreloadState>(
      PlayerEntryPreloadCoordinator.new,
    );

class PlayerEntryPreloadState {
  const PlayerEntryPreloadState({
    this.dramaId,
    this.preferredEpisodeId,
    this.trigger,
    this.isUserIntent = false,
    this.requestedAt,
  });

  final String? dramaId;
  final String? preferredEpisodeId;
  final String? trigger;
  final bool isUserIntent;
  final DateTime? requestedAt;

  bool get isFresh =>
      requestedAt != null &&
      DateTime.now().difference(requestedAt!) < const Duration(seconds: 25);
}

class PlayerEntryPreloadCoordinator extends Notifier<PlayerEntryPreloadState> {
  @override
  PlayerEntryPreloadState build() => const PlayerEntryPreloadState();

  /// 列表停稳后调用。新候选会替换旧候选，避免瀑布流同时下载多部剧。
  void prepareVisibleCandidate({
    required String dramaId,
    required String trigger,
  }) {
    _prepare(dramaId: dramaId, trigger: trigger, isUserIntent: false);
  }

  /// 普通播放器路由创建时调用，覆盖所有非 For You 入口。
  ///
  /// 此时不等待网络：路由立即展示 PlayerPage，同时复用本次启动的详情请求；若任务
  /// 已由列表可见阶段启动，保留它而不是发出第二次请求。
  void preparePlayerRoute({
    required String dramaId,
    required String episodeId,
    String? trigger,
  }) {
    _prepare(
      dramaId: dramaId,
      trigger: trigger ?? 'player_route_enter',
      isUserIntent: true,
      // `1` is the shared default for drama cards. A concrete route episode
      // (history/push/deep link) must win over a generic resume guess.
      preferredEpisodeId: episodeId == '1' ? null : episodeId,
    );
  }

  void _prepare({
    required String dramaId,
    required String trigger,
    required bool isUserIntent,
    String? preferredEpisodeId,
  }) {
    if (dramaId.isEmpty) return;
    final current = state;
    if (current.dramaId == dramaId &&
        current.preferredEpisodeId == preferredEpisodeId &&
        current.isFresh) {
      // 同剧的可见预取已在跑或完成；点击只提升语义优先级，不重启详情/HLS 请求。
      if (isUserIntent && !current.isUserIntent) {
        state = PlayerEntryPreloadState(
          dramaId: dramaId,
          preferredEpisodeId: preferredEpisodeId,
          trigger: trigger,
          isUserIntent: true,
          requestedAt: current.requestedAt,
        );
        _log('promote existing candidate', dramaId: dramaId, trigger: trigger);
      } else {
        _log('reuse fresh candidate', dramaId: dramaId, trigger: trigger);
      }
      return;
    }
    if (current.dramaId != null && current.dramaId != dramaId) {
      _log(
        'replace candidate',
        dramaId: dramaId,
        trigger: trigger,
        extra: 'previousDramaId=${current.dramaId}',
      );
    } else {
      _log('start candidate', dramaId: dramaId, trigger: trigger);
    }
    state = PlayerEntryPreloadState(
      dramaId: dramaId,
      preferredEpisodeId: preferredEpisodeId,
      trigger: trigger,
      isUserIntent: isUserIntent,
      requestedAt: DateTime.now(),
    );
    unawaited(
      ref
          .read(playerStartupPreloadControllerProvider.notifier)
          .preloadFirstPlayableDramaId(
            dramaId,
            preferredEpisodeId: preferredEpisodeId,
          ),
    );
  }

  void _log(
    String event, {
    required String dramaId,
    required String trigger,
    String? extra,
  }) {
    debugPrint(
      '[player-entry-preload] coordinator=$event dramaId=$dramaId '
      'trigger=$trigger${extra == null ? '' : ' $extra'}',
    );
  }
}
