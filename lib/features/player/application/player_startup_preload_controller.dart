import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drama/domain/drama.dart';
import '../data/drama_playback_target_repository_provider.dart';
import '../data/player_feed_repository_provider.dart';
import '../data/player_playback_source_repository_provider.dart';
import '../data/player_preload_config_provider.dart';
import '../domain/player_feed.dart';
import '../domain/drama_playback_target.dart';
import '../domain/player_preload_state.dart';
import 'player_playback_timing_trace.dart';

final playerStartupPreloadControllerProvider =
    NotifierProvider<PlayerStartupPreloadController, PlayerStartupPreloadState>(
      PlayerStartupPreloadController.new,
    );

/// 列表卡片随首页接口下发的续播提示。
///
/// 仅用于在详情返回后跳过一次本地进度读取并优先锁定预热目标；详情中的权益、地址
/// 与 watch_progress 仍是进入播放器后的最终准则。
class PlayerEntryResumeHint {
  const PlayerEntryResumeHint({
    required this.episodeId,
    required this.episodeNo,
    required this.position,
    required this.duration,
  });

  final String episodeId;
  final int episodeNo;
  final Duration position;
  final Duration duration;

  bool get canResume =>
      episodeId != '0' && position > Duration.zero && duration > Duration.zero;
}

enum PlayerStartupPreloadStatus { idle, pending, success, failed, cancelled }

/// 首页启动预热的可观测状态。
///
/// 这个状态只说明“首屏候选的 HLS/source 是否提前热过”，不代表播放器已经创建
/// media session。启动预热的结果可以被播放链路识别为 hit/miss，但不能接管播放，
/// 否则 Home 就会在用户点击前持有播放器资源。
class PlayerStartupPreloadState {
  const PlayerStartupPreloadState({
    required this.status,
    this.itemId,
    this.sourceUrl,
    this.startedAt,
    this.completedAt,
    this.error,
    this.details,
  });

  const PlayerStartupPreloadState.idle()
    : status = PlayerStartupPreloadStatus.idle,
      itemId = null,
      sourceUrl = null,
      startedAt = null,
      completedAt = null,
      error = null,
      details = null;

  /// startup preload 当前阶段。
  ///
  /// success 只代表 HLS/source 预热成功，不代表播放器已经打开。播放仍要由
  /// PlayerPlaybackController 重新接管 source 和 media session。
  final PlayerStartupPreloadStatus status;

  /// 被启动预热命中的 feed item id。
  ///
  /// Home 传入的是 drama，controller 会拉单剧 feed 后挑第一个 playable item，所以
  /// 这里保存的是 episode item id，而不是 drama id。
  final String? itemId;

  /// 启动预热时使用的原始 episode source hint。
  ///
  /// matches 会同时比较 itemId 和 sourceUrl，避免同一 item 换源后误认为预热命中。
  final String? sourceUrl;

  /// 预热开始时间。
  ///
  /// 用于 timing report 和诊断首屏预热耗时。idle/cancel 前可能为空。
  final DateTime? startedAt;

  /// 预热完成、失败或取消时间。
  ///
  /// pending 时为空。不要用它判断是否可以播放，应结合 status。
  final DateTime? completedAt;

  /// 预热失败的错误对象。
  ///
  /// 仅用于诊断和测试，不直接展示给用户。启动预热失败不应阻断用户点击播放。
  final Object? error;

  /// 预热过程的诊断细节。
  ///
  /// 可能包含 HLS playlist/segment 预热摘要。不要作为业务判断输入。
  final String? details;

  bool matches(PlayerFeedItem item) {
    final source = item.episode.videoSource;
    if (source == null) {
      return false;
    }
    return status == PlayerStartupPreloadStatus.success &&
        itemId == item.id &&
        sourceUrl == source;
  }
}

/// 首页首屏启动预热控制器。
///
/// Home 只知道 drama 卡片，不知道最终可播放 episode 和授权状态，所以这里先拉取
/// 单剧 feed，再挑第一个 playable item 做 HLS preload。Home 不能创建 media session：
/// 创建播放器会抢音频焦点、引入后台释放责任，并让首页滚动与播放页生命周期耦合。
///
/// startup preload 与 playback preload 必须使用独立 repository/preloadManager。
/// 两者的 pending/release 触发时机不同：Home 切分类或 dispose 会取消 startup，
/// 播放页隐藏会取消 playback；共享会互相误杀，导致首屏预热中断或播放器页相邻预热
/// 被首页生命周期影响。
class PlayerStartupPreloadController
    extends Notifier<PlayerStartupPreloadState> {
  int _generation = 0;
  late final PlayerPlaybackTimingTrace _timingTrace;

  @override
  PlayerStartupPreloadState build() {
    _timingTrace = PlayerPlaybackTimingTrace(sessionKey: 'startup-preload');
    final preloadManager = ref.read(playerStartupPreloadManagerProvider);
    ref.onDispose(() {
      _generation += 1;
      unawaited(preloadManager.releasePending());
    });
    return const PlayerStartupPreloadState.idle();
  }

  List<PlayerPlaybackTimingEvent> get timingEvents => _timingTrace.events;

  String exportTimingReport() {
    return _timingTrace.exportReport();
  }

  Future<void> preloadFirstPlayableDrama(Drama? drama) async {
    await preloadFirstPlayableDramaId(drama?.id);
  }

  /// 为任意普通播放器入口预取单剧首个可播放目标。
  ///
  /// 入口页通常只有 dramaId，没有 Home 的完整 [Drama] 卡片模型；预取层只需要
  /// id 来请求详情和选择可播放集，不能要求 Search/My List/推送各自伪造卡片。
  Future<void> preloadFirstPlayableDramaId(
    String? dramaId, {
    String? preferredEpisodeId,
    PlayerEntryResumeHint? resumeHint,
  }) async {
    final config = ref.read(playerPreloadConfigProvider);
    if (config.effectiveHomeStartupPreloadCount <= 0) {
      await cancel(reason: 'startup_preload_disabled');
      return;
    }

    if (dramaId == null || dramaId.isEmpty) {
      await cancel(reason: 'no candidate');
      return;
    }

    final generation = ++_generation;
    _record(
      'startup preload request',
      itemId: dramaId,
      details: 'dramaId=$dramaId',
    );
    // 每次只保留一个 startup pending。首页首屏候选变化时，旧请求继续跑只会浪费
    // 带宽，并可能把过期 drama 记录成成功命中。
    final preloadManager = ref.read(playerStartupPreloadManagerProvider);
    await preloadManager.releasePending();
    if (!_isCurrent(generation)) {
      return;
    }

    try {
      final items = await ref
          .read(playerFeedRepositoryProvider)
          .listSingleDramaFeed(dramaId: dramaId, episodeId: '1');
      if (!_isCurrent(generation)) {
        return;
      }
      // 不能预热 locked/unavailable/null source。即使 mock 数据能给出 URL，也要把
      // 可播放边界留给授权和内容状态，避免后续接真实接口时出现越权预取。
      final target = resumeHint?.canResume == true
          ? DramaPlaybackTarget(
              dramaId: dramaId,
              episodeId: resumeHint!.episodeId,
              position: resumeHint.position,
              duration: resumeHint.duration,
              updatedAt: DateTime.now(),
            )
          : await ref
                .read(dramaPlaybackTargetRepositoryProvider)
                .getForDrama(dramaId);
      if (!_isCurrent(generation)) {
        return;
      }
      // 详情已内联 `watch_progress`，与本次 episodes/is_unlocked/source_url 属于同一
      // 快照。避免再并行请求旧进度接口造成多一次网络竞争和选集不一致。
      final detailProgress = items.isEmpty
          ? null
          : items.first.content.watchProgress;
      final remoteTarget =
          detailProgress != null &&
              detailProgress.hasHistory &&
              detailProgress.duration > Duration.zero &&
              detailProgress.position <
                  detailProgress.duration - const Duration(seconds: 2)
          ? DramaPlaybackTarget(
              dramaId: dramaId,
              episodeId: detailProgress.episodeId,
              position: detailProgress.position,
              duration: detailProgress.duration,
              updatedAt: DateTime.now(),
            )
          : null;
      final item = _firstPlayableItem(
        items,
        preferredEpisodeId: preferredEpisodeId,
        remoteTarget: remoteTarget,
        target: target,
      );
      if (item == null) {
        state = PlayerStartupPreloadState(
          status: PlayerStartupPreloadStatus.cancelled,
          itemId: dramaId,
          completedAt: DateTime.now(),
          details: 'reason=no_playable_item',
        );
        _record(
          'startup preload cancelled',
          itemId: dramaId,
          details: 'reason=no_playable_item',
        );
        return;
      }

      final selectedTarget = preferredEpisodeId == item.episode.id
          ? null
          : remoteTarget?.episodeId == item.episode.id
          ? remoteTarget
          : target?.episodeId == item.episode.id
          ? target
          : null;

      debugPrint(
        '[player-entry-preload] selection dramaId=$dramaId '
        'episodeId=${item.episode.id} '
        'reason=${preferredEpisodeId == item.episode.id
            ? 'route_episode'
            : remoteTarget?.episodeId == item.episode.id
            ? 'remote_resume'
            : resumeHint?.episodeId == item.episode.id && target?.canResume == true
            ? 'home_resume_hint'
            : target?.episodeId == item.episode.id && target?.canResume == true
            ? 'local_resume'
            : 'first_playable'} '
        'positionMs=${selectedTarget?.position.inMilliseconds ?? 0}',
      );

      final source = item.episode.videoSource;
      final startedAt = DateTime.now();
      state = PlayerStartupPreloadState(
        status: PlayerStartupPreloadStatus.pending,
        itemId: item.id,
        sourceUrl: source,
        startedAt: startedAt,
      );
      _record(
        'startup preload start',
        itemId: item.id,
        source: source,
        details: [
          'dramaId=${item.content.id}',
          'episodeId=${item.episode.id}',
          if (preferredEpisodeId == item.episode.id) 'target=route_episode',
          if (selectedTarget != null)
            'targetPositionMs=${selectedTarget.position.inMilliseconds}',
        ].join(' '),
      );

      final preloadState = await ref
          .read(playerStartupPlaybackSourceRepositoryProvider)
          .preload(item, preferredPosition: selectedTarget?.position);
      if (!_isCurrent(generation)) {
        return;
      }

      final status = switch (preloadState.status) {
        PlaybackPreloadStatus.success => PlayerStartupPreloadStatus.success,
        PlaybackPreloadStatus.failed => PlayerStartupPreloadStatus.failed,
        PlaybackPreloadStatus.cancelled => PlayerStartupPreloadStatus.cancelled,
        PlaybackPreloadStatus.pending => PlayerStartupPreloadStatus.pending,
      };
      state = PlayerStartupPreloadState(
        status: status,
        itemId: item.id,
        sourceUrl: source,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        error: preloadState.error,
        details: preloadState.details,
      );
      _record(
        switch (status) {
          PlayerStartupPreloadStatus.success => 'startup preload success',
          PlayerStartupPreloadStatus.failed => 'startup preload failed',
          PlayerStartupPreloadStatus.cancelled => 'startup preload cancelled',
          PlayerStartupPreloadStatus.pending => 'startup preload pending',
          PlayerStartupPreloadStatus.idle => 'startup preload idle',
        },
        itemId: item.id,
        source: source,
        elapsed: DateTime.now().difference(startedAt),
        error: preloadState.error,
        details: preloadState.details,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = PlayerStartupPreloadState(
        status: PlayerStartupPreloadStatus.failed,
        itemId: dramaId,
        startedAt: state.startedAt,
        completedAt: DateTime.now(),
        error: error,
      );
      _record('startup preload failed', itemId: dramaId, error: error);
    }
  }

  Future<void> cancel({String reason = 'cancel', bool syncState = true}) async {
    final previous = state;
    final preloadManager = ref.read(playerStartupPreloadManagerProvider);
    // cancel 同时失效 generation 和释放 pending。这里不能调用 playback preload 的
    // release，因为 startup 和 playback 的资源作用域不同。
    _generation += 1;
    await preloadManager.releasePending();
    if (!ref.mounted) {
      return;
    }
    if (syncState && ref.mounted) {
      state = PlayerStartupPreloadState(
        status: previous.status == PlayerStartupPreloadStatus.idle
            ? PlayerStartupPreloadStatus.idle
            : PlayerStartupPreloadStatus.cancelled,
        itemId: previous.itemId,
        sourceUrl: previous.sourceUrl,
        startedAt: previous.startedAt,
        completedAt: DateTime.now(),
        details: 'reason=$reason',
      );
    }
    _record(
      'startup preload cancelled',
      itemId: previous.itemId,
      source: previous.sourceUrl,
      details: 'reason=$reason',
    );
  }

  PlayerFeedItem? _firstPlayableItem(
    List<PlayerFeedItem> items, {
    String? preferredEpisodeId,
    DramaPlaybackTarget? remoteTarget,
    DramaPlaybackTarget? target,
  }) {
    if (preferredEpisodeId != null && preferredEpisodeId.isNotEmpty) {
      for (final item in items) {
        if (item.episode.id == preferredEpisodeId &&
            !item.episode.isLocked &&
            !item.episode.isUnavailable &&
            item.episode.videoSource != null) {
          return item;
        }
      }
    }
    if (remoteTarget?.canResume ?? false) {
      for (final item in items) {
        if (item.episode.id == remoteTarget!.episodeId &&
            !item.episode.isLocked &&
            !item.episode.isUnavailable &&
            item.episode.videoSource != null) {
          return item;
        }
      }
    }
    if (target?.canResume ?? false) {
      for (final item in items) {
        if (item.episode.id == target!.episodeId &&
            !item.episode.isLocked &&
            !item.episode.isUnavailable &&
            item.episode.videoSource != null) {
          return item;
        }
      }
    }
    for (final item in items) {
      if (!item.episode.isLocked &&
          !item.episode.isUnavailable &&
          item.episode.videoSource != null) {
        return item;
      }
    }
    return null;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  void _record(
    String event, {
    String? itemId,
    String? source,
    Duration? elapsed,
    Object? error,
    String? details,
  }) {
    _timingTrace.record(
      event,
      itemId: itemId,
      source: source,
      elapsed: elapsed,
      error: error,
      details: details,
    );
    debugPrint(
      '[player-entry-preload] startup=$event itemId=${itemId ?? 'null'} '
      'elapsedMs=${elapsed?.inMilliseconds ?? 0} '
      '${details ?? ''}${error == null ? '' : ' error=$error'}',
    );
  }
}
