import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_paths.dart';
import 'player_startup_preload_controller.dart';

export 'player_startup_preload_controller.dart' show PlayerEntryResumeHint;

const playerEntryPreloadDefaultMaxWait = Duration(milliseconds: 1500);

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
  int? episodeNo,
  required String trigger,
  PlayerEntryResumeHint? resumeHint,
}) {
  ProviderScope.containerOf(context, listen: false)
      .read(playerEntryPreloadCoordinatorProvider.notifier)
      .preparePlayerRoute(
        dramaId: dramaId,
        episodeId: episodeId,
        episodeNo: episodeNo,
        trigger: trigger,
        resumeHint: resumeHint,
      );
}

Future<T?> openPlayerWithEntryPreload<T>(
  BuildContext context, {
  required String dramaId,
  required String episodeId,
  int? episodeNo,
  required String trigger,
  int? userActionAtMs,
  PlayerEntryResumeHint? resumeHint,
  Object? extra,
  Duration maxWait = playerEntryPreloadDefaultMaxWait,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  OverlayEntry? loadingOverlay;
  var waitCompleted = false;
  final waitFuture = container
      .read(playerEntryPreloadCoordinatorProvider.notifier)
      .preparePlayerRouteAndWait(
        dramaId: dramaId,
        episodeId: episodeId,
        episodeNo: episodeNo,
        trigger: trigger,
        resumeHint: resumeHint,
        maxWait: maxWait,
      )
      .whenComplete(() {
        waitCompleted = true;
      });
  final loadingDelay = Future<void>.delayed(const Duration(milliseconds: 180));
  await Future.any([waitFuture, loadingDelay]);
  if (!context.mounted) {
    return null;
  }
  if (!waitCompleted) {
    loadingOverlay = OverlayEntry(
      builder: (_) => const _PlayerEntryLoadingOverlay(),
    );
    overlay?.insert(loadingOverlay);
  }

  final waitResult = await waitFuture;
  const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
  if (shouldPrint) {
    debugPrint(
      '[player-entry-preload] wait_result ${waitResult.diagnosticSummary}',
    );
  }
  loadingOverlay?.remove();
  if (!context.mounted) return null;
  return context.push<T>(
    RoutePaths.playerLocation(
      dramaId: dramaId,
      episodeId: episodeId,
      trigger: trigger,
      userActionAtMs: userActionAtMs,
    ),
    extra: extra,
  );
}

enum PlayerEntryPreloadWaitStatus { ready, failed, timeout, cancelled }

class PlayerEntryPreloadWaitResult {
  const PlayerEntryPreloadWaitResult({
    required this.status,
    required this.waitDuration,
    this.dramaId,
    this.itemId,
    this.sourceUrl,
  });

  final PlayerEntryPreloadWaitStatus status;
  final Duration waitDuration;
  final String? dramaId;
  final String? itemId;
  final String? sourceUrl;

  bool get shouldNavigate => true;

  String get diagnosticSummary {
    return [
      'status=${status.name}',
      'waitMs=${waitDuration.inMilliseconds}',
      'dramaId=${dramaId ?? 'null'}',
      'itemId=${itemId ?? 'null'}',
      'hasSource=${sourceUrl != null && sourceUrl!.isNotEmpty}',
    ].join(' ');
  }
}

class PlayerEntryPreloadState {
  const PlayerEntryPreloadState({
    this.dramaId,
    this.preferredEpisodeId,
    this.preferredEpisodeNo,
    this.trigger,
    this.isUserIntent = false,
    this.requestedAt,
    this.resumeHint,
  });

  final String? dramaId;
  final String? preferredEpisodeId;
  final int? preferredEpisodeNo;
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
    int? episodeNo,
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
      preferredEpisodeNo: episodeNo,
      resumeHint: resumeHint,
    );
  }

  Future<PlayerEntryPreloadWaitResult> preparePlayerRouteAndWait({
    required String dramaId,
    required String episodeId,
    int? episodeNo,
    String? trigger,
    PlayerEntryResumeHint? resumeHint,
    Duration maxWait = playerEntryPreloadDefaultMaxWait,
  }) async {
    preparePlayerRoute(
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: episodeNo,
      trigger: trigger,
      resumeHint: resumeHint,
    );
    final startedAt = DateTime.now();
    Duration elapsed() => DateTime.now().difference(startedAt);
    while (DateTime.now().difference(startedAt) < maxWait) {
      final startupState = ref.read(playerStartupPreloadControllerProvider);
      if (startupState.dramaId == dramaId) {
        switch (startupState.status) {
          case PlayerStartupPreloadStatus.success:
            return PlayerEntryPreloadWaitResult(
              status: PlayerEntryPreloadWaitStatus.ready,
              waitDuration: elapsed(),
              dramaId: startupState.dramaId,
              itemId: startupState.itemId,
              sourceUrl: startupState.sourceUrl,
            );
          case PlayerStartupPreloadStatus.failed:
            return PlayerEntryPreloadWaitResult(
              status: PlayerEntryPreloadWaitStatus.failed,
              waitDuration: elapsed(),
              dramaId: startupState.dramaId,
              itemId: startupState.itemId,
              sourceUrl: startupState.sourceUrl,
            );
          case PlayerStartupPreloadStatus.cancelled:
            return PlayerEntryPreloadWaitResult(
              status: PlayerEntryPreloadWaitStatus.cancelled,
              waitDuration: elapsed(),
              dramaId: startupState.dramaId,
              itemId: startupState.itemId,
              sourceUrl: startupState.sourceUrl,
            );
          case PlayerStartupPreloadStatus.idle:
          case PlayerStartupPreloadStatus.pending:
            break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    final startupState = ref.read(playerStartupPreloadControllerProvider);
    return PlayerEntryPreloadWaitResult(
      status: PlayerEntryPreloadWaitStatus.timeout,
      waitDuration: elapsed(),
      dramaId: startupState.dramaId == dramaId ? startupState.dramaId : dramaId,
      itemId: startupState.dramaId == dramaId ? startupState.itemId : null,
      sourceUrl: startupState.dramaId == dramaId
          ? startupState.sourceUrl
          : null,
    );
  }

  void _prepare({
    required String dramaId,
    required String trigger,
    required bool isUserIntent,
    String? preferredEpisodeId,
    int? preferredEpisodeNo,
    PlayerEntryResumeHint? resumeHint,
  }) {
    if (dramaId.isEmpty) return;
    final current = state;
    final startupPreload = ref.read(playerStartupPreloadControllerProvider);
    if (!isUserIntent &&
        current.isUserIntent &&
        current.dramaId != null &&
        current.dramaId != dramaId &&
        current.isFresh) {
      _log(
        'ignore visible candidate',
        dramaId: dramaId,
        trigger: trigger,
        extra: 'protectedDramaId=${current.dramaId}',
      );
      return;
    }
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
        current.preferredEpisodeNo == preferredEpisodeNo &&
        (_sameResumeHint(current.resumeHint, resumeHint) ||
            routeFallbackCanReuseHint ||
            startupTargetMatchesRouteResume) &&
        current.isFresh) {
      // 同剧的可见预取已在跑或完成；点击只提升语义优先级，不重启详情/HLS 请求。
      if (isUserIntent && !current.isUserIntent) {
        state = PlayerEntryPreloadState(
          dramaId: dramaId,
          preferredEpisodeId: preferredEpisodeId,
          preferredEpisodeNo: preferredEpisodeNo,
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
      preferredEpisodeNo: preferredEpisodeNo,
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
            preferredEpisodeNo: preferredEpisodeNo,
            resumeHint: resumeHint,
            reuseMatchingCurrent: isUserIntent,
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

class _PlayerEntryLoadingOverlay extends StatelessWidget {
  const _PlayerEntryLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x99000000),
        child: IgnorePointer(
          child: Center(
            child: Semantics(
              label: 'Preparing video',
              liveRegion: true,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
