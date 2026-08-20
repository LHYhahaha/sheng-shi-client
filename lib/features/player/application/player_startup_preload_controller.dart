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
    this.dramaId,
    this.itemId,
    this.sourceUrl,
    this.startedAt,
    this.completedAt,
    this.error,
    this.details,
    this.retainedCandidates = const [],
  });

  const PlayerStartupPreloadState.idle()
    : status = PlayerStartupPreloadStatus.idle,
      dramaId = null,
      itemId = null,
      sourceUrl = null,
      startedAt = null,
      completedAt = null,
      error = null,
      details = null,
      retainedCandidates = const [];

  /// startup preload 当前阶段。
  ///
  /// success 只代表 HLS/source 预热成功，不代表播放器已经打开。播放仍要由
  /// PlayerPlaybackController 重新接管 source 和 media session。
  final PlayerStartupPreloadStatus status;

  /// 当前拥有 startup 网络资格的短剧。列表滚动切换候选时，旧剧会从这里移入
  /// [retainedCandidates]；已完成的 HLS 数据仍由内存/磁盘缓存保存。
  final String? dramaId;

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

  /// 最近被新曝光候选替换的启动预热记录。
  ///
  /// 这里只保留少量元数据，不保存视频字节；playlist/完整分片由 HLS 缓存负责。
  /// pending 记录代表已停止后续预热，已完整落盘的资源仍可复用。
  final List<PlayerStartupRetainedCandidate> retainedCandidates;

  bool matches(PlayerFeedItem item) {
    final source = item.episode.videoSource;
    if (source == null) {
      return false;
    }
    if (status == PlayerStartupPreloadStatus.success &&
        itemId == item.id &&
        sourceUrl == source) {
      return true;
    }
    return retainedCandidates.any(
      (candidate) =>
          candidate.status == PlayerStartupPreloadStatus.success &&
          candidate.itemId == item.id &&
          candidate.sourceUrl == source,
    );
  }
}

/// 已被新的可见卡片替换、但仍保留缓存可复用价值的启动预热记录。
class PlayerStartupRetainedCandidate {
  const PlayerStartupRetainedCandidate({
    required this.dramaId,
    required this.itemId,
    required this.sourceUrl,
    required this.status,
    required this.retainedAt,
  });

  final String dramaId;
  final String itemId;
  final String sourceUrl;
  final PlayerStartupPreloadStatus status;
  final DateTime retainedAt;
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
  static const _maxRetainedCandidates = 3;

  int _generation = 0;
  final _retainedCandidates = <PlayerStartupRetainedCandidate>[];
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

    if (state.dramaId != null && state.dramaId != dramaId) {
      _retainCurrentCandidate(reason: 'visible_candidate_replaced');
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
      // 本地索引在点击时就开始读取；它比未刷新的首页卡片更接近用户上次离开时的
      // 位置。地址仍必须等待详情返回，但不能等详情后再额外发起一次本地读取。
      final localTargetFuture = ref
          .read(dramaPlaybackTargetRepositoryProvider)
          .getForDrama(dramaId);
      final items = await ref
          .read(playerFeedRepositoryProvider)
          .listSingleDramaFeed(dramaId: dramaId, episodeId: '1');
      if (!_isCurrent(generation)) {
        return;
      }
      // 不能预热 locked/unavailable/null source。即使 mock 数据能给出 URL，也要把
      // 可播放边界留给授权和内容状态，避免后续接真实接口时出现越权预取。
      DramaPlaybackTarget? localTarget;
      try {
        localTarget = await localTargetFuture;
      } catch (_) {
        // 本地索引只优化目标选择，读取失败仍使用首页/详情续播信息。
      }
      if (!_isCurrent(generation)) {
        return;
      }
      final entryTarget = resumeHint?.canResume == true
          ? DramaPlaybackTarget(
              dramaId: dramaId,
              episodeId: resumeHint!.episodeId,
              position: resumeHint.position,
              duration: resumeHint.duration,
              updatedAt: DateTime.now(),
            )
          : null;
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
        localTarget: localTarget,
        entryTarget: entryTarget,
        remoteTarget: remoteTarget,
      );
      if (item == null) {
        state = PlayerStartupPreloadState(
          status: PlayerStartupPreloadStatus.cancelled,
          dramaId: dramaId,
          itemId: dramaId,
          completedAt: DateTime.now(),
          details: 'reason=no_playable_item',
          retainedCandidates: _retainedSnapshot(),
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
          : localTarget?.episodeId == item.episode.id &&
                localTarget?.canResume == true
          ? localTarget
          : entryTarget?.episodeId == item.episode.id &&
                entryTarget?.canResume == true
          ? entryTarget
          : remoteTarget?.episodeId == item.episode.id
          ? remoteTarget
          : null;

      const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
      if (shouldPrint) {
        debugPrint(
          '[player-entry-preload] selection dramaId=$dramaId '
          'episodeId=${item.episode.id} '
          'reason=${preferredEpisodeId == item.episode.id
              ? 'route_episode'
              : localTarget?.episodeId == item.episode.id && localTarget?.canResume == true
              ? 'local_resume'
              : entryTarget?.episodeId == item.episode.id && entryTarget?.canResume == true
              ? 'home_resume_hint'
              : remoteTarget?.episodeId == item.episode.id
              ? 'detail_resume'
              : 'first_playable'} '
          'positionMs=${selectedTarget?.position.inMilliseconds ?? 0}',
        );
      }

      final source = item.episode.videoSource;
      final startedAt = DateTime.now();
      state = PlayerStartupPreloadState(
        status: PlayerStartupPreloadStatus.pending,
        dramaId: dramaId,
        itemId: item.id,
        sourceUrl: source,
        startedAt: startedAt,
        retainedCandidates: _retainedSnapshot(),
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
        dramaId: dramaId,
        itemId: item.id,
        sourceUrl: source,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        error: preloadState.error,
        details: preloadState.details,
        retainedCandidates: _retainedSnapshot(),
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
        dramaId: dramaId,
        itemId: dramaId,
        startedAt: state.startedAt,
        completedAt: DateTime.now(),
        error: error,
        retainedCandidates: _retainedSnapshot(),
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
        dramaId: previous.dramaId,
        itemId: previous.itemId,
        sourceUrl: previous.sourceUrl,
        startedAt: previous.startedAt,
        completedAt: DateTime.now(),
        details: 'reason=$reason',
        retainedCandidates: _retainedSnapshot(),
      );
    }
    _record(
      'startup preload cancelled',
      itemId: previous.itemId,
      source: previous.sourceUrl,
      details: 'reason=$reason',
    );
  }

  /// 真实播放器开始消费同剧 source 时调用。保留已在飞行的 playlist/segment，且
  /// 将后续尚未发起的两条关键段请求标记为 playback 优先级。
  void promotePendingForActivePlayback({
    required String itemId,
    required String sourceUrl,
  }) {
    final pending = state;
    if (pending.status != PlayerStartupPreloadStatus.pending ||
        pending.itemId != itemId ||
        pending.sourceUrl != sourceUrl) {
      return;
    }
    ref.read(startupHlsPlaylistPreloaderProvider).promotePendingToPlayback();
    _record(
      'startup critical segment relay promoted',
      itemId: itemId,
      source: sourceUrl,
      details: 'priority=playback',
    );
  }

  PlayerFeedItem? _firstPlayableItem(
    List<PlayerFeedItem> items, {
    String? preferredEpisodeId,
    DramaPlaybackTarget? localTarget,
    DramaPlaybackTarget? entryTarget,
    DramaPlaybackTarget? remoteTarget,
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
    if (localTarget?.canResume ?? false) {
      for (final item in items) {
        if (item.episode.id == localTarget!.episodeId &&
            !item.episode.isLocked &&
            !item.episode.isUnavailable &&
            item.episode.videoSource != null) {
          return item;
        }
      }
    }
    if (entryTarget?.canResume ?? false) {
      for (final item in items) {
        if (item.episode.id == entryTarget!.episodeId &&
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

  void _retainCurrentCandidate({required String reason}) {
    final current = state;
    final dramaId = current.dramaId;
    final itemId = current.itemId;
    final sourceUrl = current.sourceUrl;
    if (dramaId == null || itemId == null || sourceUrl == null) return;

    // 旧的 in-flight 预热通过 releasePending 停止后续调度；已经完成的 playlist/
    // segment 会继续留在 HLS 内存与磁盘缓存。这里保留成功或暂停记录，让后续点击
    // 可以被诊断为已预热命中，而不是被新的候选状态覆盖掉。
    final retainedStatus = current.status == PlayerStartupPreloadStatus.pending
        ? PlayerStartupPreloadStatus.cancelled
        : current.status;
    _retainedCandidates.removeWhere(
      (candidate) => candidate.dramaId == dramaId,
    );
    _retainedCandidates.insert(
      0,
      PlayerStartupRetainedCandidate(
        dramaId: dramaId,
        itemId: itemId,
        sourceUrl: sourceUrl,
        status: retainedStatus,
        retainedAt: DateTime.now(),
      ),
    );
    if (_retainedCandidates.length > _maxRetainedCandidates) {
      _retainedCandidates.removeRange(
        _maxRetainedCandidates,
        _retainedCandidates.length,
      );
    }
    _record(
      'startup preload retained',
      itemId: itemId,
      source: sourceUrl,
      details:
          'dramaId=$dramaId reason=$reason status=${retainedStatus.name} '
          'retainedCount=${_retainedCandidates.length}',
    );
  }

  List<PlayerStartupRetainedCandidate> _retainedSnapshot() =>
      List.unmodifiable(_retainedCandidates);

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
    const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
    if (shouldPrint) {
      debugPrint(
        '[player-entry-preload] startup=$event itemId=${itemId ?? 'null'} '
        'elapsedMs=${elapsed?.inMilliseconds ?? 0} '
        '${details ?? ''}${error == null ? '' : ' error=$error'}',
      );
    }
  }
}
