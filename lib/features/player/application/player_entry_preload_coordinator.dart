import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drama/domain/drama_watch_progress.dart';

import 'player_startup_preload_controller.dart';

export 'player_startup_preload_controller.dart' show PlayerEntryResumeHint;

/// 把各列表的统一观看进度转换为普通播放器入口提示。
///
/// 进度为全零时不传提示，让播放器按新剧规则从第 1 集开始。
PlayerEntryResumeHint? playerEntryResumeHintFor(DramaWatchProgress? progress) {
  if (progress?.canResume != true) return null;
  return PlayerEntryResumeHint(
    episodeId: progress!.episodeId,
    episodeNo: progress.episodeNo,
    position: Duration(seconds: progress.positionSeconds),
    duration: Duration(seconds: progress.durationSeconds),
  );
}

/// 普通播放器入口的统一预取调度。
///
/// For You 有独立的 feed/session 预热，不能走这里；其余入口无论来自首页、搜索、
/// 收藏、会员推荐、弹窗还是深链，都会先经过此处。这样详情 Future 与 HLS 分片预热
/// 只保留一个候选，真实播放发生时再由 PlaybackController 抢占网络优先级。
final playerEntryPreloadCoordinatorProvider =
    NotifierProvider<PlayerEntryPreloadCoordinator, PlayerEntryPreloadState>(
      PlayerEntryPreloadCoordinator.new,
    );

/// 在用户点击普通播放器入口的同一事件循环内提交预热。
///
/// 入口 UI 不必持有 WidgetRef；统一从当前 ProviderScope 取得 coordinator。路由层
/// 仍会做一次去重兜底，保证深链、通知等非点击入口也覆盖到。
void preparePlayerEntryPreload(
  BuildContext context, {
  required String dramaId,
  required String episodeId,
  required String trigger,
  PlayerEntryResumeHint? resumeHint,
}) {
  ProviderScope.containerOf(context, listen: false)
      .read(playerEntryPreloadCoordinatorProvider.notifier)
      .preparePlayerRoute(
        dramaId: dramaId,
        episodeId: episodeId,
        trigger: trigger,
        resumeHint: resumeHint,
      );
}

class PlayerEntryPreloadState {
  const PlayerEntryPreloadState({
    this.dramaId,
    this.preferredEpisodeId,
    this.trigger,
    this.isUserIntent = false,
    this.requestedAt,
    this.resumeHint,
  });

  final String? dramaId;
  final String? preferredEpisodeId;
  final String? trigger;
  final bool isUserIntent;
  final DateTime? requestedAt;
  final PlayerEntryResumeHint? resumeHint;

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
    PlayerEntryResumeHint? resumeHint,
  }) {
    _prepare(
      dramaId: dramaId,
      trigger: trigger ?? 'player_route_enter',
      isUserIntent: true,
      // `1` is the shared default for drama cards. A concrete route episode
      // (history/push/deep link) must win over a generic resume guess.
      preferredEpisodeId: episodeId == '1' ? null : episodeId,
      resumeHint: resumeHint,
    );
  }

  void _prepare({
    required String dramaId,
    required String trigger,
    required bool isUserIntent,
    String? preferredEpisodeId,
    PlayerEntryResumeHint? resumeHint,
  }) {
    if (dramaId.isEmpty) return;
    final current = state;
    final startupPreload = ref.read(playerStartupPreloadControllerProvider);
    // 卡片点击已携带首页的 watch_progress；随后路由层会以没有 hint 的兜底调用
    // 一次。后者不能覆盖前者，否则会重新启动详情/playlist 预热并丢失目标集。
    final routeFallbackCanReuseHint =
        resumeHint == null && current.resumeHint != null;
    // 可见卡片预热本身会在详情返回后选择续播集，因此 coordinator 的 resumeHint
    // 仍可能为空。若用户点击时携带的首页进度恰好对应这个已选中的 episode，不能
    // 因为“hint 从无到有”重置已有 playlist/关键分片任务；只提升为用户意图并
    // 把 hint 留给播放页。
    final startupTargetMatchesRouteResume =
        resumeHint?.canResume == true &&
        startupPreload.itemId == 'single:$dramaId:${resumeHint!.episodeId}' &&
        (startupPreload.status == PlayerStartupPreloadStatus.pending ||
            startupPreload.status == PlayerStartupPreloadStatus.success);
    if (current.dramaId == dramaId &&
        current.preferredEpisodeId == preferredEpisodeId &&
        (_sameResumeHint(current.resumeHint, resumeHint) ||
            routeFallbackCanReuseHint ||
            startupTargetMatchesRouteResume) &&
        current.isFresh) {
      // 同剧的可见预取已在跑或完成；点击只提升语义优先级，不重启详情/HLS 请求。
      if (isUserIntent && !current.isUserIntent) {
        state = PlayerEntryPreloadState(
          dramaId: dramaId,
          preferredEpisodeId: preferredEpisodeId,
          trigger: trigger,
          isUserIntent: true,
          requestedAt: current.requestedAt,
          resumeHint: resumeHint ?? current.resumeHint,
        );
        _log(
          'promote existing candidate',
          dramaId: dramaId,
          trigger: trigger,
          extra: startupTargetMatchesRouteResume
              ? 'reason=startup_target_matches_resume'
              : null,
        );
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
      resumeHint: resumeHint,
    );
    unawaited(
      ref
          .read(playerStartupPreloadControllerProvider.notifier)
          .preloadFirstPlayableDramaId(
            dramaId,
            preferredEpisodeId: preferredEpisodeId,
            resumeHint: resumeHint,
          ),
    );
  }

  bool _sameResumeHint(
    PlayerEntryResumeHint? left,
    PlayerEntryResumeHint? right,
  ) =>
      left?.episodeId == right?.episodeId &&
      left?.position == right?.position &&
      left?.duration == right?.duration;

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
