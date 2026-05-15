import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/playback_progress_repository_provider.dart';
import '../data/player_playback_source_repository_provider.dart';
import '../data/player_preload_config_provider.dart';
import '../domain/player_feed.dart';
import '../domain/player_playback_progress.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import 'player_playback_prepare_manager.dart';
import 'player_playback_timing_trace.dart';
import 'player_rebuild_diagnostics.dart';
import 'player_session_controller.dart';
import 'player_startup_preload_controller.dart';

final playerPlaybackSessionFactoryProvider =
    Provider<PlayerPlaybackSession Function()>((ref) {
      return MediaKitPlayerSession.new;
    });

/// 统一创建 prepared/retained media session 的工厂。
///
/// 这里故意通过 provider 注入，而不是在 UI 或控制器里直接 new 播放器实例：
/// 播放器资源、测试替身和真机生命周期都必须从同一个入口约束，否则很容易出现
/// 多个 session 抢音频焦点、测试无法隔离或 dispose 顺序不可控的问题。
final playerPlaybackPrepareManagerFactoryProvider =
    Provider<PlayerPlaybackPrepareManager Function()>((ref) {
      final sessionFactory = ref.watch(playerPlaybackSessionFactoryProvider);
      return () => PlayerPlaybackPrepareManager(sessionFactory: sessionFactory);
    });

final playerPlaybackControllerProvider =
    NotifierProvider.family<
      PlayerPlaybackController,
      PlayerPlaybackState,
      String
    >(PlayerPlaybackController.new);

class PlayerPlaybackSessionKeys {
  const PlayerPlaybackSessionKeys._();

  /// For You tab 使用稳定 session key，离开 tab 时暂停但保留 provider 生命周期。
  ///
  /// 这样底部 tab 来回切换不会不断重建播放器；真正释放由可见性、内存压力和
  /// provider dispose 路径负责。
  static const forYouTab = 'for-you-tab';

  /// 单剧播放页每个页面实例使用独立 key。
  ///
  /// 单剧页从首页或列表进入时可能同时存在多个 route 实例。不要只用 drama/episode
  /// 作为 key，否则旧页面的 dispose 可能误释放新页面正在播放的 session。
  static String singleDrama({
    required String? dramaId,
    required String? episodeId,
    Object? instanceId,
  }) {
    final suffix = instanceId == null ? '' : ':$instanceId';
    return 'single:$dramaId:$episodeId$suffix';
  }
}

enum PlayerPlaybackStatus {
  idle,
  opening,
  playing,
  paused,
  blocked,
  waitUnlock,
  unavailable,
  error,
}

enum PlayerVideoSurfaceLifecycle { attached, detaching, detached, disposing }

enum PlayerPlaybackErrorKind {
  recoverableNetwork,
  sourceResolve,
  mediaFatal,
  unknown,
}

class PlayerPlaybackState {
  const PlayerPlaybackState({
    required this.videoController,
    required this.status,
    required this.hasFirstFrame,
    required this.isBuffering,
    required this.preloadedItemIds,
    required this.preloadStates,
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.isSeeking,
    required this.hasEnded,
    required this.playbackRate,
    required this.surfaceLifecycle,
    this.currentItemId,
    this.currentSource,
    this.seekPreviewPosition,
    this.error,
    this.errorKind,
  });

  const PlayerPlaybackState.initial({VideoController? videoController})
    : this(
        videoController: videoController,
        status: PlayerPlaybackStatus.idle,
        hasFirstFrame: false,
        isBuffering: false,
        preloadedItemIds: const [],
        preloadStates: const [],
        position: Duration.zero,
        duration: Duration.zero,
        bufferedPosition: Duration.zero,
        isSeeking: false,
        hasEnded: false,
        playbackRate: 1.0,
        surfaceLifecycle: videoController == null
            ? PlayerVideoSurfaceLifecycle.detached
            : PlayerVideoSurfaceLifecycle.attached,
      );

  /// 当前页面应该绑定到 `Video` 组件的 media_kit 控制器。
  ///
  /// 它只在当前 session 可展示时存在；`disposeSession` 会清空，避免 UI 继续持有已释放
  /// 的播放器。不要在 UI 层缓存这个对象，播放器 session 被 prepared takeover 替换时
  /// 这里会更新为新的 controller。
  final VideoController? videoController;

  /// 播放状态机的主状态。
  ///
  /// UI 应优先读这个字段判断 idle/opening/playing/paused/blocked/unavailable/error，
  /// 不要只通过 `videoController` 或 source 是否为空推断播放态；locked 和 unavailable
  /// 都可能没有 source，但它们不是错误。
  final PlayerPlaybackStatus status;

  /// 当前 source 是否已经收到可渲染首帧。
  ///
  /// 首帧由播放器 width stream 推进。它和 `playing` 不是同一件事：HLS 可能先出音频或
  /// position，再出画面。UI 的加载遮罩、黑屏规避和 timing trace 都依赖这个字段。
  final bool hasFirstFrame;

  /// 当前播放器是否处于缓冲中。
  ///
  /// 这个字段只描述当前 source，不描述 HLS preload pending。首帧后的可恢复网络错误
  /// 也会把这里置为 true，用于保留画面并提示等待。
  final bool isBuffering;

  /// 已经完成 HLS HTTP 预热的 item id 列表。
  ///
  /// 它只代表 playlist/segment 预热成功，不代表 media session 已打开，也不代表用户
  /// 有权限播放。不要用这个列表跳过 source resolve 或授权判断。
  final List<String> preloadedItemIds;

  /// 每个相邻 item 的 HLS preload 细节状态。
  ///
  /// 用于调试、测试和 UI 观测 pending/failed/cancelled。这个列表的生命周期跟播放页
  /// 可见性绑定，页面隐藏或 generation 变化时可能被清理。
  final List<PlaybackPreloadState> preloadStates;

  /// 当前播放位置。
  ///
  /// 来自 media session position stream，并会被 seek 和进度恢复修正。拖动进度条时
  /// UI 展示应读 `displayedPosition`，不要直接用它覆盖用户正在拖动的预览位置。
  final Duration position;

  /// 当前媒体总时长。
  ///
  /// HLS 打开初期可能为 0，只有大于 0 时才允许 seek 和计算进度比例。不要用 0 判定
  /// 播放失败，它也可能只是播放器尚未解析完 manifest。
  final Duration duration;

  /// 当前播放器已缓冲到的位置。
  ///
  /// 它是 media session 对当前 source 的缓冲进度，不包含后台 HLS preload 的数据。
  /// 进度恢复时会至少抬到恢复位置，避免 UI 显示“播放位置超过缓冲”。
  final Duration bufferedPosition;

  /// 用户是否正在拖动 seek bar。
  ///
  /// seek 期间 position stream 仍可能继续推送，控制器会避免用流更新覆盖预览态。
  /// PageView 也会据此禁用纵向滑动，防止拖进度时误切集。
  final bool isSeeking;

  /// 当前 source 是否已经自然播放结束。
  ///
  /// 自动下一集和中心播放按钮依赖它。seek 到结尾附近会短暂忽略 completed 事件，避免
  /// 用户拖动到末尾时被误判为自然完播。
  final bool hasEnded;

  /// 当前播放倍速。
  ///
  /// 倍速属于 session 状态，For You 和单剧通过不同 sessionKey 隔离。不要把它放成
  /// 全局设置，避免一个播放器页面影响另一个。
  final double playbackRate;

  /// 当前 Android/iOS 视频 surface 的挂载生命周期。
  ///
  /// 它只描述 `Video` widget 是否应该继续绑定 `videoController`，不替代播放状态。
  /// Android `media_kit_video` 的 native resize/wid callback 可能晚于 widget dispose
  /// 到达，所以离开页面或隐藏播放器时必须先进入 detaching/disposing 并清空
  /// `videoController`，等 Flutter 树卸载 surface 后再释放底层 player。
  final PlayerVideoSurfaceLifecycle surfaceLifecycle;

  /// 当前播放链路绑定的 feed item id。
  ///
  /// 它用于防止旧异步结果覆盖新 item、匹配 prepared/retained session、记录 timing。
  /// blocked/unavailable 状态也会保留 item id，便于 UI 展示对应遮罩。
  final String? currentItemId;

  /// 当前播放器实际打开或准备打开的 source。
  ///
  /// 这里可能是远端 HLS URL，也可能是 local proxy spike 生成的 localhost URL。业务层
  /// 不应把它当成原始内容 URL 保存，原始 URL 在 PlaybackSource.remoteUrl 中。
  final String? currentSource;

  /// seek 拖动过程中的预览位置。
  ///
  /// 只有 `isSeeking` 时才有意义；取消或结束 seek 会清空。这样 UI 可以展示预览气泡，
  /// 同时不提前污染真实 position。
  final Duration? seekPreviewPosition;

  /// 当前播放链路最后一次错误对象。
  ///
  /// 这个字段用于调试和错误 UI，不应直接把错误对象展示给用户。用户文案应根据
  /// `errorKind/status` 映射，避免泄漏 URL、SDK 异常或内部状态。
  final Object? error;

  /// 当前错误的业务分类。
  ///
  /// 分类用于区分可恢复网络错误、source resolve 失败和 media fatal。UI 与重试策略
  /// 应依赖这个稳定枚举，不要解析底层错误字符串。
  final PlayerPlaybackErrorKind? errorKind;

  bool get isPlaying => status == PlayerPlaybackStatus.playing;
  bool get isOpening => status == PlayerPlaybackStatus.opening;
  bool get isError => status == PlayerPlaybackStatus.error;
  bool get isReady =>
      hasFirstFrame &&
      !isBuffering &&
      (status == PlayerPlaybackStatus.playing ||
          status == PlayerPlaybackStatus.paused);
  bool get isLoading =>
      currentSource != null &&
      !isError &&
      (isOpening || isBuffering || !hasFirstFrame);
  bool get isSeekAllowed =>
      currentSource != null &&
      duration > Duration.zero &&
      (status == PlayerPlaybackStatus.playing ||
          status == PlayerPlaybackStatus.paused);

  /// 当前播放层是否允许 UI 保持可播放 surface 相关交互。
  ///
  /// 这个判断只看生命周期，不要求一定有真实 `VideoController`。widget tests 会使用
  /// 没有 native surface 的 fake session，但仍需要验证 loading、点击暂停和重试等播放层
  /// 行为；真正的 `Video` widget 挂载仍由 `canMountVideoSurface` 保护。
  bool get shouldAttachVideoSurface =>
      surfaceLifecycle == PlayerVideoSurfaceLifecycle.attached;

  /// 当前是否可以把真实 `VideoController` 挂到 Flutter 树上。
  ///
  /// Android teardown 的 late callback 风险发生在这里：只有 attached 且 controller 存在时
  /// 才允许挂载，detaching/disposing 阶段必须先从树上摘掉，再释放底层 player。
  bool get canMountVideoSurface =>
      shouldAttachVideoSurface && videoController != null;
  Duration get displayedPosition => seekPreviewPosition ?? position;
  double get progressValue => _durationRatio(displayedPosition);
  double get bufferedValue => _durationRatio(bufferedPosition);

  PlayerPlaybackState copyWith({
    PlayerPlaybackStatus? status,
    bool? hasFirstFrame,
    bool? isBuffering,
    List<String>? preloadedItemIds,
    List<PlaybackPreloadState>? preloadStates,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isSeeking,
    bool? hasEnded,
    double? playbackRate,
    PlayerVideoSurfaceLifecycle? surfaceLifecycle,
    VideoController? videoController,
    String? currentItemId,
    String? currentSource,
    Duration? seekPreviewPosition,
    Object? error,
    PlayerPlaybackErrorKind? errorKind,
    bool clearError = false,
    bool clearSource = false,
    bool clearVideoController = false,
    bool clearSeekPreview = false,
  }) {
    return PlayerPlaybackState(
      videoController: clearVideoController
          ? null
          : videoController ?? this.videoController,
      status: status ?? this.status,
      hasFirstFrame: clearSource ? false : hasFirstFrame ?? this.hasFirstFrame,
      isBuffering: clearSource ? false : isBuffering ?? this.isBuffering,
      preloadedItemIds: preloadedItemIds ?? this.preloadedItemIds,
      preloadStates: preloadStates ?? this.preloadStates,
      position: clearSource ? Duration.zero : position ?? this.position,
      duration: clearSource ? Duration.zero : duration ?? this.duration,
      bufferedPosition: clearSource
          ? Duration.zero
          : bufferedPosition ?? this.bufferedPosition,
      isSeeking: clearSource ? false : isSeeking ?? this.isSeeking,
      hasEnded: clearSource ? false : hasEnded ?? this.hasEnded,
      playbackRate: playbackRate ?? this.playbackRate,
      surfaceLifecycle:
          surfaceLifecycle ??
          (clearVideoController
              ? PlayerVideoSurfaceLifecycle.detached
              : this.surfaceLifecycle),
      currentItemId: clearSource
          ? currentItemId
          : currentItemId ?? this.currentItemId,
      currentSource: clearSource ? null : currentSource ?? this.currentSource,
      seekPreviewPosition: clearSource || clearSeekPreview
          ? null
          : seekPreviewPosition ?? this.seekPreviewPosition,
      error: clearError ? null : error ?? this.error,
      errorKind: clearError ? null : errorKind ?? this.errorKind,
    );
  }

  double _durationRatio(Duration value) {
    if (duration <= Duration.zero) {
      return 0;
    }
    return (value.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// 播放器核心状态机，负责把 feed item 转成可播放 source、media session 和 UI 状态。
///
/// 这个控制器是播放器链路的业务边界：UI 只提交“播放哪个 item / 用户做了什么”，
/// 不直接创建 repository、Dio/HTTP client 或播放器 session。这样做是为了保证
/// source resolve、HLS preload、prepared session window、进度恢复和 timing trace
/// 都能用同一套 generation/cancel/release 规则串起来。绕过这里会让隐藏页继续播放、
/// locked 内容被预热、或旧异步结果覆盖新页面状态。
///
/// 重要边界：
/// - startup preload 只预热首页首个可播放 source，不能接管 media session。
/// - playback preload 只在播放器页相邻 item 范围内工作，不能共享 startup 的 pending/release。
/// - prepared media session window 固定服务 previous/current/next，不能随着 HLS preload count 扩大。
/// - locked/unavailable/null source 不能 resolve、preload、open 或 prepare。
class PlayerPlaybackController extends Notifier<PlayerPlaybackState> {
  PlayerPlaybackController(this.sessionKey);

  /// Android texture / surface 销毁后 native resize callback 可能晚到。
  ///
  /// 页面退出和 provider teardown 时先 pause、卸载 Video surface，再延迟 dispose media
  /// player，可以避免 media_kit_video 在 Android integration test teardown 中对已释放
  /// player 调 `setProperty`。普通业务 dispose 默认不延迟，只有 UI teardown 路径显式传入。
  static const videoSurfaceTeardownDelay = Duration(milliseconds: 450);

  static bool get shouldDelayVideoSurfaceTeardown {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final WidgetsBinding binding;
    try {
      binding = WidgetsBinding.instance;
    } catch (_) {
      return false;
    }
    // 普通 widget tests 使用 AutomatedTestWidgetsFlutterBinding。这里不启用真实延迟，
    // 避免 fake_async 把 teardown timer 判定为泄漏；Android integration test 和真机
    // runtime 仍启用延迟，覆盖 media_kit_video native resize callback 晚到的问题。
    return binding.runtimeType.toString() !=
        'AutomatedTestWidgetsFlutterBinding';
  }

  final String sessionKey;
  late PlayerPlaybackSession _session;
  late final PlayerPlaybackPreloadManager _preloadManager;
  late final PlayerPlaybackPrepareManager _prepareManager;
  late final PlaybackProgressRepository _progressRepository;
  var _subscriptions = <StreamSubscription<dynamic>>[];
  final _preloadedItemIds = <String>{};
  final _preloadStates = <String, PlaybackPreloadState>{};
  final _preparingItemIds = <String>{};
  var _activePreloadAllowedIds = <String>{};
  int _generation = 0;
  int _preloadGeneration = 0;
  bool _pauseWhenOpenCompletes = false;
  String? _accessOverlayPausedItemId;
  bool _isSessionDisposed = false;
  bool _wasPlayingBeforeSeek = false;
  bool _ignoreNextCompleted = false;
  Duration? _lastPositionUpdate;
  late final _timingTrace = PlayerPlaybackTimingTrace(sessionKey: sessionKey);
  final _playingBeforeFirstFrameLoggedItemIds = <String>{};
  final _positionBeforeFirstFrameLoggedItemIds = <String>{};
  final _firstPositionLoggedItemIds = <String>{};
  final _surfaceBeforeFirstFrameLoggedItemIds = <String>{};
  DateTime? _playingBeforeFirstFrameAt;
  DateTime? _positionBeforeFirstFrameAt;
  String? _currentPlaybackItemId;
  PlaybackSource? _currentPlaybackSource;
  bool _currentPlaybackHasFirstFrame = false;
  Duration _currentPlaybackPosition = Duration.zero;
  Duration _currentPlaybackDuration = Duration.zero;
  Duration _currentPlaybackBufferedPosition = Duration.zero;

  List<PlayerPlaybackTimingEvent> get timingEvents => _timingTrace.events;

  List<PlayerPlaybackTimingEvent> get debugTimingEvents => timingEvents;

  String exportTimingReport() {
    return _timingTrace.exportReport();
  }

  void recordVideoSurfaceShownBeforeFirstFrame({
    required String itemId,
    String? source,
  }) {
    if (!_surfaceBeforeFirstFrameLoggedItemIds.add(itemId)) {
      return;
    }
    _logTiming(
      'video surface shown before firstFrame',
      itemId: itemId,
      source: source,
      details: _timingDetails([
        'status=${state.status.name}',
        'positionMs=${state.position.inMilliseconds}',
      ]),
    );
  }

  void recordPlaybackUserAction(
    String event, {
    String? trigger,
    String? fromItemId,
    String? toItemId,
    String? direction,
    int? fromIndex,
    int? toIndex,
    DateTime? occurredAt,
  }) {
    _timingTrace.recordUserAction(
      event,
      trigger: trigger,
      fromItemId: fromItemId,
      toItemId: toItemId,
      direction: direction,
      fromIndex: fromIndex,
      toIndex: toIndex,
      occurredAt: occurredAt,
    );
  }

  void recordPlaybackTiming(
    String event, {
    String? itemId,
    String? source,
    Duration? elapsed,
    Object? error,
    String? details,
  }) {
    _logTiming(
      event,
      itemId: itemId,
      source: source,
      elapsed: elapsed,
      error: error,
      details: details,
    );
  }

  @override
  PlayerPlaybackState build() {
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _preloadManager = ref.read(playerPlaybackPreloadManagerProvider);
    _prepareManager = ref.read(playerPlaybackPrepareManagerFactoryProvider)();
    _prepareManager.timingLogger = _logTiming;
    _progressRepository = ref.read(playbackProgressRepositoryProvider);
    _attachSessionStreams(_session);
    _logTiming('create current session', details: 'reason=build');
    ref.onDispose(() {
      // provider dispose 是最后一道兜底：必须同时释放流、HTTP 预加载、prepared
      // window 和当前播放器。这里不依赖 UI dispose，因为 tab、route、后台切换的
      // 生命周期触发顺序并不总是稳定。
      unawaited(_cancelSessionStreams());
      unawaited(_disposePreloads(syncState: false));
      unawaited(_releaseSessionWindowFor('provider dispose'));
      unawaited(
        _disposeSessionOnly(
          disposeDelay: shouldDelayVideoSurfaceTeardown
              ? videoSurfaceTeardownDelay
              : Duration.zero,
        ),
      );
    });
    return PlayerPlaybackState.initial(
      videoController: _session.videoController,
    );
  }

  Future<void> playItem(
    PlayerFeedItem? item, {
    bool resumeIfCurrentSource = false,
  }) async {
    if (_isSessionDisposed) {
      return;
    }

    _startPlaybackTrace(item);

    _logTiming(
      'play item request',
      itemId: item?.id,
      source: item?.episode.videoSource,
      details: _timingDetails([
        'requestedItemId=${item?.id ?? 'null'}',
        'currentItemId=${state.currentItemId ?? 'null'}',
        'requestedSource=${item?.episode.videoSource ?? 'null'}',
        'currentSource=${state.currentSource ?? 'null'}',
        'status=${state.status.name}',
        'hasCurrentSessionSnapshot=${_currentPlaybackSource != null}',
        'windowItems=${_windowItemsText()}',
      ]),
    );
    if (item != null &&
        !item.episode.isLocked &&
        !item.episode.isUnavailable &&
        item.episode.videoSource != null) {
      final startupPreload = ref.read(playerStartupPreloadControllerProvider);
      final isStartupHit = startupPreload.matches(item);
      _logTiming(
        isStartupHit
            ? 'startup preload hit on playItem'
            : 'startup preload miss on playItem',
        itemId: item.id,
        source: item.episode.videoSource,
        details: _timingDetails([
          'startupStatus=${startupPreload.status.name}',
          'startupItemId=${startupPreload.itemId ?? 'null'}',
          'startupSource=${startupPreload.sourceUrl ?? 'null'}',
        ]),
      );
    }

    if (item == null) {
      // 空 item 表示 feed 当前没有可播放目标。需要暂停并清掉 source，但不把它记为
      // error，否则空列表/切分类会误触发播放失败 UI。
      _accessOverlayPausedItemId = null;
      final generation = ++_generation;
      if (!await _pauseIfCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.idle,
        clearSource: true,
        clearError: true,
        surfaceLifecycle: PlayerVideoSurfaceLifecycle.detaching,
        clearVideoController: true,
      );
      _currentPlaybackItemId = null;
      _currentPlaybackSource = null;
      _clearCurrentPlaybackSnapshot();
      return;
    }

    if (item.episode.isLocked) {
      // 锁定内容是业务付费边界，不能为了“预热体验”提前 resolve/open。
      // 客户端 mock 可以展示 paywall，但真实环境必须等服务端授权后再拿 source。
      _accessOverlayPausedItemId = null;
      await _blockPlaybackForItem(
        item,
        status: PlayerPlaybackStatus.blocked,
        reason: 'locked item play request',
      );
      return;
    }

    final sourceHint = item.episode.videoSource;
    if (item.episode.isUnavailable || sourceHint == null) {
      // unavailable/null source 代表内容侧暂不可播放。这里同样只进入状态展示，
      // 不触发 repository，避免把内容缺失误判成网络错误或污染 preload 缓存。
      _accessOverlayPausedItemId = null;
      await _blockPlaybackForItem(
        item,
        status: PlayerPlaybackStatus.unavailable,
        reason: item.episode.isUnavailable
            ? 'unavailable item play request'
            : 'null source play request',
      );
      return;
    }

    final isSameSource =
        state.currentItemId == item.id &&
        state.currentSource != null &&
        state.status != PlayerPlaybackStatus.error;
    if (isSameSource && !state.hasEnded) {
      if (state.surfaceLifecycle != PlayerVideoSurfaceLifecycle.attached) {
        state = state.copyWith(
          videoController: _session.videoController,
          surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
        );
      }
      final shouldResumeDetachedCurrent =
          resumeIfCurrentSource &&
          _accessOverlayPausedItemId == item.id &&
          state.status == PlayerPlaybackStatus.paused &&
          state.currentSource != null;
      if (shouldResumeDetachedCurrent) {
        _pauseWhenOpenCompletes = false;
        _accessOverlayPausedItemId = null;
        _logTiming(
          'same source access overlay resume',
          itemId: item.id,
          source: state.currentSource,
        );
        await _session.play();
        if (!ref.mounted) {
          return;
        }
        state = state.copyWith(
          status: PlayerPlaybackStatus.playing,
          hasEnded: false,
          videoController: _session.videoController,
          surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
        );
      }
      return;
    }

    final generation = ++_generation;
    _logTiming(
      'trace generation assigned',
      itemId: item.id,
      source: sourceHint,
      details: 'generation=$generation',
    );
    _pauseWhenOpenCompletes = false;
    _accessOverlayPausedItemId = null;
    final resumeProgress = _shouldPersistProgress
        ? await _progressRepository.getProgress(item.id)
        : null;
    state = state.copyWith(
      status: PlayerPlaybackStatus.opening,
      hasFirstFrame: false,
      isBuffering: true,
      position: Duration.zero,
      duration: Duration.zero,
      bufferedPosition: Duration.zero,
      isSeeking: false,
      hasEnded: false,
      currentItemId: item.id,
      currentSource: sourceHint,
      clearError: true,
      clearSeekPreview: true,
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );

    var didResolveSource = false;
    try {
      final windowItemsBeforeTake = _windowItemsText();
      // prepared/retained 命中时直接接管已经 open 的 session，避免同一个 item
      // 重复 open。命中窗口只覆盖相邻滑动，不承诺覆盖所有 HLS preload 候选。
      final prepared = _prepareManager.takeIfMatches(item.id);
      _logTiming(
        'take window session',
        itemId: item.id,
        source: prepared?.source.playableSource ?? sourceHint,
        details: _timingDetails([
          'requestedItemId=${item.id}',
          'hit=${prepared != null}',
          if (prepared != null) 'kind=${prepared.kind.name}',
          if (prepared != null) 'isOpened=${prepared.isOpened}',
          if (prepared != null) 'firstFrameReady=${prepared.hasFirstFrame}',
          if (prepared != null)
            'playbackAdvanced=${prepared.hasPlaybackAdvanced}',
          if (prepared != null)
            'positionMs=${prepared.position.inMilliseconds}',
          'windowItemsBefore=$windowItemsBeforeTake',
          'windowItemsAfter=${_windowItemsText()}',
        ]),
      );
      if (prepared != null) {
        final hitEvent = prepared.kind == PreparedPlaybackSessionKind.retained
            ? 'retained hit previous'
            : 'prepared hit next';
        _logTiming(
          hitEvent,
          itemId: item.id,
          source: prepared.source.playableSource,
          details: _timingDetails([
            'window=hit',
            'isOpened=${prepared.isOpened}',
            'firstFrameReady=${prepared.hasFirstFrame}',
            'playbackAdvanced=${prepared.hasPlaybackAdvanced}',
          ]),
        );
        await _replaceCurrentSession(prepared);
        if (!ref.mounted || !_isCurrent(generation)) {
          await _session.pause();
          return;
        }
        state = state.copyWith(
          videoController: _session.videoController,
          surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
          currentSource: prepared.source.playableSource,
          hasFirstFrame: prepared.hasFirstFrame,
          position: prepared.position,
          duration: prepared.duration,
          bufferedPosition: prepared.bufferedPosition,
        );
        _currentPlaybackHasFirstFrame = prepared.hasFirstFrame;
        _currentPlaybackPosition = prepared.position;
        _currentPlaybackDuration = prepared.duration;
        _currentPlaybackBufferedPosition = prepared.bufferedPosition;
        await _restoreProgressIfNeeded(resumeProgress, generation);
        if (!ref.mounted || !_isCurrent(generation)) {
          return;
        }
        if (_pauseWhenOpenCompletes) {
          await _session.pause();
          state = state.copyWith(
            status: PlayerPlaybackStatus.paused,
            isBuffering: false,
          );
          return;
        }
        await _session.setVolume(100);
        _logTiming('session play called', itemId: item.id, source: sourceHint);
        await _session.play();
        if (!ref.mounted || !_isCurrent(generation)) {
          return;
        }
        state = state.copyWith(
          status: PlayerPlaybackStatus.playing,
          isBuffering: !prepared.hasFirstFrame,
          hasEnded: false,
        );
        return;
      }

      _logTiming(
        'window miss fallback open',
        itemId: item.id,
        source: sourceHint,
        details: _timingDetails(['window=miss', 'firstFrameReady=false']),
      );
      // fallback open 前先把当前已出首帧的 session 收进 retained window。
      // 这样用户快速回滑能复用 previous；如果直接 dispose，回滑会重新走 resolve/open。
      await _retainCurrentBeforeNormalOpen(item.id);
      if (!ref.mounted || !_isCurrent(generation)) {
        return;
      }
      _logTiming('list entry normal open', itemId: item.id, source: sourceHint);
      final resolveStartedAt = DateTime.now();
      _logTiming('source resolve start', itemId: item.id, source: sourceHint);
      final playbackSource = await ref
          .read(playerPlaybackSourceRepositoryProvider)
          .resolve(item);
      didResolveSource = true;
      _logTiming(
        'source resolve end',
        itemId: item.id,
        source: playbackSource.playableSource,
        elapsed: DateTime.now().difference(resolveStartedAt),
      );
      if (!ref.mounted) {
        return;
      }
      if (!_isCurrent(generation)) {
        return;
      }
      _currentPlaybackSource = playbackSource;
      _currentPlaybackItemId = item.id;
      _clearCurrentPlaybackSnapshot();
      state = state.copyWith(currentSource: playbackSource.playableSource);
      final openStartedAt = DateTime.now();
      _logTiming(
        'media open start',
        itemId: item.id,
        source: playbackSource.playableSource,
      );
      _logTiming(
        'session play called',
        itemId: item.id,
        source: playbackSource.playableSource,
        details: 'reason=media open play=true',
      );
      await _session.open(playbackSource.playableSource, play: true);
      _logTiming(
        'media open end',
        itemId: item.id,
        source: playbackSource.playableSource,
        elapsed: DateTime.now().difference(openStartedAt),
      );
      if (!ref.mounted) {
        return;
      }
      if (!_isCurrent(generation)) {
        if (_pauseWhenOpenCompletes &&
            state.currentSource == playbackSource.playableSource) {
          await _session.pause();
        }
        return;
      }
      await _restoreProgressIfNeeded(resumeProgress, generation);
      if (!ref.mounted || !_isCurrent(generation)) {
        return;
      }
      if (_pauseWhenOpenCompletes) {
        await _session.pause();
        state = state.copyWith(
          status: PlayerPlaybackStatus.paused,
          isBuffering: false,
        );
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.playing,
        isBuffering: false,
        hasEnded: false,
      );
    } catch (error) {
      final errorKind = didResolveSource
          ? PlayerPlaybackErrorKind.mediaFatal
          : PlayerPlaybackErrorKind.sourceResolve;
      _logTiming(
        'error',
        itemId: item.id,
        source: sourceHint,
        error: error,
        details: 'kind=${errorKind.name}',
      );
      if (!_isCurrent(generation)) {
        return;
      }
      _currentPlaybackItemId = null;
      _currentPlaybackSource = null;
      _clearCurrentPlaybackSnapshot();
      state = state.copyWith(
        status: PlayerPlaybackStatus.error,
        hasFirstFrame: false,
        isBuffering: false,
        error: error,
        errorKind: errorKind,
      );
    }
  }

  Future<void> preloadAround(
    List<PlayerFeedItem> items,
    int currentIndex,
  ) async {
    if (_isSessionDisposed) {
      return;
    }

    if (items.isEmpty) {
      await _disposePreloads();
      _preloadStates.clear();
      _preloadedItemIds.clear();
      _syncPreloadState();
      return;
    }

    final skipped = <String>[];
    final config = ref.read(playerPreloadConfigProvider);
    final isForYou = items[currentIndex].mode == PlayerFeedMode.forYou;
    final forwardPreloadCount = config.forwardHlsPreloadCountFor(isForYou);
    final backwardPreloadCount = config.backwardHlsPreloadCountFor(isForYou);
    // HLS preload 只挑可播放的相邻 source。locked/unavailable/null source 不占有效名额，
    // 否则一个付费或下架 item 会把真正可预热的下一集挤掉。
    final forwardCandidates = _preloadCandidatesInDirection(
      items,
      currentIndex,
      direction: 1,
      count: forwardPreloadCount,
      skipped: skipped,
    );
    final candidates = <PlayerFeedItem>[
      ...forwardCandidates,
      ..._preloadCandidatesInDirection(
        items,
        currentIndex,
        direction: -1,
        count: backwardPreloadCount,
        skipped: skipped,
      ),
    ];

    // HLS preload count 控制 HTTP playlist/segment 预热，不控制 prepared session window。
    // prepared session 持有播放器和解码资源，扩大到多个 next/previous 会提高内存、
    // 音频焦点和后台释放风险，所以这里即使 HLS count 变大也只选择 HTTP 候选集合。
    final maxPreloadedSources = forwardPreloadCount + backwardPreloadCount;
    final selectedCandidates = candidates
        .take(maxPreloadedSources)
        .toList(growable: false);
    final allowedIds = selectedCandidates.map((item) => item.id).toSet();
    if (state.currentItemId != null) {
      allowedIds.add(state.currentItemId!);
    }
    final previousActivePreloadAllowedIds = _activePreloadAllowedIds.toSet();
    _logTiming(
      'preload candidates',
      itemId: state.currentItemId,
      details: _timingDetails([
        'currentIndex=$currentIndex',
        'candidates=${candidates.map((candidate) => candidate.id).join(',')}',
        'skipped=${skipped.join(',')}',
        'allowedIds=${allowedIds.join(',')}',
        'activePreloadAllowedIds=${previousActivePreloadAllowedIds.join(',')}',
        'forwardHlsPreloadCount=$forwardPreloadCount',
        'backwardHlsPreloadCount=$backwardPreloadCount',
        'maxConcurrentHlsPreloads=${config.effectiveMaxConcurrentHlsPreloads}',
      ]),
    );
    final preloadGeneration = setEquals(_activePreloadAllowedIds, allowedIds)
        ? _preloadGeneration
        : ++_preloadGeneration;
    _activePreloadAllowedIds = allowedIds;

    _preloadedItemIds.removeWhere((id) => !allowedIds.contains(id));
    _cancelPreloadsNotIn(allowedIds);
    await _retainSessionWindowOnly(
      allowedIds,
      reason: 'stale generation/window trim',
    );

    _syncPreloadState();

    if (state.currentItemId != null && state.currentSource != null) {
      final nextItem = forwardCandidates.isEmpty
          ? null
          : forwardCandidates.first;
      if (nextItem != null) {
        // 只 prepare 第一个 forward playable item，保持 previous/current/next 窗口。
        // 不要按 HLS preload 数量循环 prepare，否则会变成播放器实例池。
        unawaited(_prepareNextItem(nextItem, preloadGeneration));
      }
    }

    for (final item in selectedCandidates) {
      final currentPreload = _preloadStates[item.id];
      if (_preloadedItemIds.contains(item.id) ||
          currentPreload?.status == PlaybackPreloadStatus.pending) {
        continue;
      }
      _setPreloadState(
        PlaybackPreloadState(
          itemId: item.id,
          sourceUrl: item.episode.videoSource!,
          status: PlaybackPreloadStatus.pending,
          startedAt: DateTime.now(),
        ),
      );
      try {
        final preloadStartedAt = DateTime.now();
        _logTiming(
          'preload start',
          itemId: item.id,
          source: item.episode.videoSource,
        );
        final result = await ref
            .read(playerPlaybackSourceRepositoryProvider)
            .preload(item);
        _logTiming(
          'preload end',
          itemId: item.id,
          source: item.episode.videoSource,
          elapsed: DateTime.now().difference(preloadStartedAt),
          details: result.details == null
              ? result.status.name
              : '${result.status.name} | ${result.details}',
        );
        if (!ref.mounted ||
            _isSessionDisposed ||
            preloadGeneration != _preloadGeneration) {
          return;
        }
        _setPreloadState(result);
        if (result.status == PlaybackPreloadStatus.success) {
          _preloadedItemIds.add(item.id);
        } else {
          _preloadedItemIds.remove(item.id);
        }
        _syncPreloadState();
      } catch (error) {
        _logTiming(
          'preload error',
          itemId: item.id,
          source: item.episode.videoSource,
          error: error,
        );
        if (!ref.mounted ||
            _isSessionDisposed ||
            preloadGeneration != _preloadGeneration) {
          return;
        }
        _preloadedItemIds.remove(item.id);
        _setPreloadState(
          PlaybackPreloadState(
            itemId: item.id,
            sourceUrl: item.episode.videoSource!,
            status: PlaybackPreloadStatus.failed,
            startedAt: _preloadStates[item.id]?.startedAt ?? DateTime.now(),
            completedAt: DateTime.now(),
            error: error,
          ),
        );
      }
    }
  }

  Future<void> blockItem(
    PlayerFeedItem item, {
    PlayerPlaybackStatus status = PlayerPlaybackStatus.blocked,
    String reason = 'access denied',
  }) {
    final blockedStatus = switch (status) {
      PlayerPlaybackStatus.blocked ||
      PlayerPlaybackStatus.waitUnlock ||
      PlayerPlaybackStatus.unavailable => status,
      _ => PlayerPlaybackStatus.blocked,
    };
    return _blockPlaybackForItem(item, status: blockedStatus, reason: reason);
  }

  Future<void> quiesceForAccessOverlay(
    PlayerFeedItem item, {
    String reason = 'access overlay',
  }) async {
    if (_isSessionDisposed) {
      return;
    }
    final shouldResumeCurrentLater =
        state.currentItemId != null &&
        (state.status == PlayerPlaybackStatus.playing ||
            state.status == PlayerPlaybackStatus.opening);
    if (shouldResumeCurrentLater) {
      _accessOverlayPausedItemId = state.currentItemId;
    }
    _pauseWhenOpenCompletes = true;
    final generation = ++_generation;
    _logTiming(
      'access overlay quiesce',
      itemId: item.id,
      source: item.episode.videoSource,
      details: _timingDetails([
        'reason=$reason',
        'wasCurrentItem=${state.currentItemId ?? 'null'}',
        'wasCurrentSource=${state.currentSource ?? 'null'}',
        'windowItems=${_windowItemsText()}',
      ]),
    );
    await _session.pause();
    if (!ref.mounted || !_isCurrent(generation)) {
      return;
    }
    state = state.copyWith(
      status:
          state.currentSource == null ||
              state.status == PlayerPlaybackStatus.idle ||
              state.status == PlayerPlaybackStatus.error
          ? state.status
          : PlayerPlaybackStatus.paused,
      isBuffering: false,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.detaching,
      clearVideoController: true,
    );
  }

  List<PlayerFeedItem> _preloadCandidatesInDirection(
    List<PlayerFeedItem> items,
    int currentIndex, {
    required int direction,
    required int count,
    required List<String> skipped,
  }) {
    if (count <= 0) {
      return const [];
    }

    final candidates = <PlayerFeedItem>[];
    var index = currentIndex + direction;
    while (index >= 0 && index < items.length && candidates.length < count) {
      final item = items[index];
      final source = item.episode.videoSource;
      final skipReasons = <String>[
        if (item.episode.isLocked) 'locked',
        if (item.episode.isUnavailable) 'unavailable',
        if (source == null) 'null_source',
        if (item.id == state.currentItemId) 'current_item',
      ];
      if (skipReasons.isEmpty) {
        candidates.add(item);
      } else {
        skipped.add('${item.id}:${skipReasons.join('+')}');
      }
      index += direction;
    }

    if (candidates.length < count && (index < 0 || index >= items.length)) {
      skipped.add('index:$index:out_of_range');
    }
    return candidates;
  }

  Future<void> togglePlay() async {
    if (_isSessionDisposed) {
      return;
    }

    if (state.status == PlayerPlaybackStatus.playing) {
      _accessOverlayPausedItemId = null;
      await _session.pause();
      state = state.copyWith(status: PlayerPlaybackStatus.paused);
      return;
    }

    if (state.status != PlayerPlaybackStatus.paused ||
        state.currentSource == null) {
      return;
    }

    _pauseWhenOpenCompletes = false;
    if (state.hasEnded) {
      await _session.seek(Duration.zero);
      _ignoreNextCompleted = false;
      _currentPlaybackPosition = Duration.zero;
      state = state.copyWith(position: Duration.zero, hasEnded: false);
    }
    await _session.play();
    state = state.copyWith(
      status: PlayerPlaybackStatus.playing,
      hasEnded: false,
    );
  }

  Future<void> replay() async {
    if (_isSessionDisposed || state.currentSource == null) {
      return;
    }
    _pauseWhenOpenCompletes = false;
    await _session.seek(Duration.zero);
    _ignoreNextCompleted = false;
    _currentPlaybackPosition = Duration.zero;
    await _session.play();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.playing,
      position: Duration.zero,
      hasEnded: false,
      clearSeekPreview: true,
    );
  }

  Future<void> setPlaybackRate(double rate) async {
    if (_isSessionDisposed || rate <= 0) {
      return;
    }
    await _session.setRate(rate);
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(playbackRate: rate);
  }

  Future<void> pause() async {
    if (_isSessionDisposed) {
      return;
    }
    _accessOverlayPausedItemId = null;
    await _session.pause();
    state = state.copyWith(status: PlayerPlaybackStatus.paused);
  }

  void beginSeek() {
    if (!state.isSeekAllowed || _isSessionDisposed) {
      return;
    }
    _wasPlayingBeforeSeek = state.status == PlayerPlaybackStatus.playing;
    state = state.copyWith(
      isSeeking: true,
      seekPreviewPosition: state.position,
    );
  }

  void updateSeekPreview(Duration position) {
    if (!state.isSeeking || !state.isSeekAllowed) {
      return;
    }
    state = state.copyWith(seekPreviewPosition: _clampToDuration(position));
  }

  Future<void> endSeek() async {
    if (!state.isSeeking || !state.isSeekAllowed || _isSessionDisposed) {
      state = state.copyWith(isSeeking: false, clearSeekPreview: true);
      return;
    }
    final target = _clampToDuration(
      state.seekPreviewPosition ?? state.position,
    );
    _currentPlaybackPosition = target;
    state = state.copyWith(position: target, isSeeking: false);
    _saveProgressIfNeeded(position: target);
    _ignoreNextCompleted =
        state.duration > Duration.zero &&
        target >= state.duration - const Duration(milliseconds: 500);
    await _session.seek(target);
    if (_wasPlayingBeforeSeek) {
      await _session.play();
      if (ref.mounted) {
        state = state.copyWith(
          status: PlayerPlaybackStatus.playing,
          hasEnded: false,
          clearSeekPreview: true,
        );
      }
    } else if (ref.mounted) {
      state = state.copyWith(
        status: PlayerPlaybackStatus.paused,
        hasEnded: false,
        clearSeekPreview: true,
      );
    }
  }

  void cancelSeek() {
    if (!state.isSeeking) {
      return;
    }
    state = state.copyWith(isSeeking: false, clearSeekPreview: true);
  }

  Future<void> pauseForVisibility({bool syncState = true}) {
    return detachSurfaceForVisibility(syncState: syncState);
  }

  Future<void> detachSurfaceForVisibility({bool syncState = true}) async {
    if (_isSessionDisposed) {
      return;
    }
    // 页面隐藏、切 tab、进后台都走这里。generation 先失效旧 open，避免异步 open
    // 完成后又自动 play；随后释放 session window 和 HTTP preload，防止隐藏页面继续
    // 占用音频/网络资源。
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    ++_generation;
    await _session.pause();
    await _releaseSessionWindowFor('hidden');
    await _disposePreloads(syncState: syncState);
    if (!syncState || !ref.mounted) {
      return;
    }
    state = state.copyWith(
      status:
          state.currentSource == null ||
              state.status == PlayerPlaybackStatus.blocked ||
              state.status == PlayerPlaybackStatus.waitUnlock ||
              state.status == PlayerPlaybackStatus.unavailable ||
              state.status == PlayerPlaybackStatus.error ||
              state.status == PlayerPlaybackStatus.idle
          ? state.status
          : PlayerPlaybackStatus.paused,
      isBuffering: false,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.detaching,
      clearVideoController: true,
    );
  }

  /// 在路由退出或测试 teardown 前先让 UI 卸载 `Video` surface。
  ///
  /// Android 的 media_kit_video 可能在 native texture resize callback 晚到时触达
  /// 已 dispose 的 `VideoController` 内部 notifier。先清空 state 里的 videoController，
  /// 让 Flutter 树有机会卸载 `Video`，随后再 dispose media session，可以降低 late
  /// resize callback 打到已释放 notifier 的概率。这个方法不改变播放业务决策，只服务
  /// 页面退出时的资源释放顺序。
  Future<void> detachSurfaceForDispose({bool syncState = true}) async {
    if (_isSessionDisposed) {
      return;
    }
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    ++_generation;
    await _session.pause();
    await _releaseSessionWindowFor('dispose surface detach');
    await _disposePreloads(syncState: syncState);
    if (!syncState || !ref.mounted) {
      return;
    }
    state = state.copyWith(
      status: state.status == PlayerPlaybackStatus.playing
          ? PlayerPlaybackStatus.paused
          : state.status,
      isBuffering: false,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.disposing,
      clearVideoController: true,
    );
  }

  void markSurfaceDetached() {
    if (!ref.mounted) {
      return;
    }
    if (state.surfaceLifecycle == PlayerVideoSurfaceLifecycle.attached) {
      return;
    }
    state = state.copyWith(
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.detached,
      clearVideoController: true,
    );
  }

  void detachVideoSurfaceForTeardown() {
    if (!ref.mounted || state.videoController == null) {
      return;
    }
    _accessOverlayPausedItemId = null;
    state = state.copyWith(
      status: state.status == PlayerPlaybackStatus.playing
          ? PlayerPlaybackStatus.paused
          : state.status,
      isBuffering: false,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.disposing,
      clearVideoController: true,
    );
  }

  Future<void> disposeSession({
    bool syncState = true,
    Duration disposeDelay = Duration.zero,
  }) async {
    // 单剧页离开时做强释放：当前 session、prepared window、HLS pending 都要清掉。
    // For You tab 不走 disposeSession，而是 pauseForVisibility，以保留 tab provider。
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    ++_generation;
    await _releaseSessionWindowFor('dispose');
    await _disposePreloads(syncState: syncState);
    _preloadStates.clear();
    _preloadedItemIds.clear();
    await _disposeSessionOnly(disposeDelay: disposeDelay);
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
    if (!syncState || !ref.mounted) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.idle,
      clearSource: true,
      clearError: true,
      preloadedItemIds: const [],
      preloadStates: const [],
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.detached,
      clearVideoController: true,
    );
  }

  Future<void> releaseSessionWindow() {
    return _releaseSessionWindowFor('memory pressure');
  }

  void _handleBuffering(bool isBuffering) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null ||
        state.status == PlayerPlaybackStatus.error ||
        state.status == PlayerPlaybackStatus.blocked ||
        state.status == PlayerPlaybackStatus.waitUnlock ||
        state.status == PlayerPlaybackStatus.unavailable) {
      return;
    }
    _logTiming(isBuffering ? 'buffering start' : 'buffering end');
    state = state.copyWith(isBuffering: isBuffering);
  }

  void _handlePlaying(bool isPlaying) {
    if (!ref.mounted) {
      return;
    }
    if (_pauseWhenOpenCompletes && isPlaying) {
      return;
    }
    if (state.currentSource == null ||
        state.status == PlayerPlaybackStatus.error ||
        state.status == PlayerPlaybackStatus.blocked ||
        state.status == PlayerPlaybackStatus.waitUnlock ||
        state.status == PlayerPlaybackStatus.unavailable ||
        state.status == PlayerPlaybackStatus.opening) {
      return;
    }
    if (isPlaying &&
        !state.hasFirstFrame &&
        state.currentItemId != null &&
        _playingBeforeFirstFrameLoggedItemIds.add(state.currentItemId!)) {
      _playingBeforeFirstFrameAt = DateTime.now();
      _logTiming(
        'playing event while hasFirstFrame=false',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails([
          'positionMs=${state.position.inMilliseconds}',
          'status=${state.status.name}',
        ]),
      );
    }
    _logTiming(
      isPlaying ? 'playingStream true' : 'playingStream false',
      itemId: state.currentItemId,
      source: state.currentSource,
      details: _timingDetails([
        'hasFirstFrame=${state.hasFirstFrame}',
        'positionMs=${state.position.inMilliseconds}',
      ]),
    );
    state = state.copyWith(
      status: isPlaying
          ? PlayerPlaybackStatus.playing
          : PlayerPlaybackStatus.paused,
      hasEnded: isPlaying ? false : state.hasEnded,
    );
  }

  void _handleCompleted(bool completed) {
    if (!ref.mounted) {
      return;
    }
    if (completed && _ignoreNextCompleted) {
      _ignoreNextCompleted = false;
      return;
    }
    if (!completed ||
        _pauseWhenOpenCompletes ||
        state.currentSource == null ||
        state.isSeeking ||
        state.status == PlayerPlaybackStatus.error ||
        state.status == PlayerPlaybackStatus.blocked ||
        state.status == PlayerPlaybackStatus.waitUnlock ||
        state.status == PlayerPlaybackStatus.unavailable ||
        state.status == PlayerPlaybackStatus.idle) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.paused,
      isBuffering: false,
      hasEnded: true,
    );
  }

  void _handlePosition(Duration position) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null || state.isSeeking) {
      return;
    }
    final clamped = _clampToDuration(position);
    final last = _lastPositionUpdate;
    if (last != null &&
        (clamped - last).abs() < const Duration(milliseconds: 250)) {
      return;
    }
    _lastPositionUpdate = clamped;
    _currentPlaybackPosition = clamped;
    if (clamped > Duration.zero &&
        state.currentItemId != null &&
        _firstPositionLoggedItemIds.add(state.currentItemId!)) {
      _logTiming(
        'position first advanced',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails(['positionMs=${clamped.inMilliseconds}']),
      );
    }
    if (!state.hasFirstFrame &&
        clamped > Duration.zero &&
        state.currentItemId != null &&
        _positionBeforeFirstFrameLoggedItemIds.add(state.currentItemId!)) {
      _positionBeforeFirstFrameAt = DateTime.now();
      _logTiming(
        'position advancing while hasFirstFrame=false',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails(['positionMs=${clamped.inMilliseconds}']),
      );
    }
    state = state.copyWith(position: clamped);
    _saveProgressIfNeeded(position: clamped);
  }

  void _handleDuration(Duration duration) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null) {
      return;
    }
    final normalized = duration < Duration.zero ? Duration.zero : duration;
    _currentPlaybackDuration = normalized;
    state = state.copyWith(duration: normalized);
    _saveProgressIfNeeded(duration: normalized);
  }

  void _handleBufferedPosition(Duration position) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null) {
      return;
    }
    final clamped = _clampToDuration(position);
    _currentPlaybackBufferedPosition = clamped;
    state = state.copyWith(bufferedPosition: clamped);
  }

  void _handleRate(double rate) {
    if (!ref.mounted) {
      return;
    }
    if (rate <= 0) {
      return;
    }
    state = state.copyWith(playbackRate: rate);
  }

  void _handleWidth(int? width) {
    if (!ref.mounted) {
      return;
    }
    if (width == null || width <= 0 || state.currentSource == null) {
      return;
    }
    if (!state.hasFirstFrame) {
      final now = DateTime.now();
      _logTiming(
        'first frame received',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails([
          'width=$width',
          if (_playingBeforeFirstFrameAt != null)
            'firstFrameDelayAfterPlayingMs=${now.difference(_playingBeforeFirstFrameAt!).inMilliseconds}',
          if (_positionBeforeFirstFrameAt != null)
            'firstFrameDelayAfterPositionMs=${now.difference(_positionBeforeFirstFrameAt!).inMilliseconds}',
          if (_playingBeforeFirstFrameAt != null ||
              _positionBeforeFirstFrameAt != null)
            'audioPlayingBeforeFirstFrameMs=${now.difference((_playingBeforeFirstFrameAt ?? _positionBeforeFirstFrameAt)!).inMilliseconds}',
        ]),
      );
    }
    _playingBeforeFirstFrameAt = null;
    _positionBeforeFirstFrameAt = null;
    state = state.copyWith(
      status: state.status == PlayerPlaybackStatus.opening
          ? PlayerPlaybackStatus.playing
          : state.status,
      hasFirstFrame: true,
      isBuffering: false,
    );
    _currentPlaybackHasFirstFrame = true;
  }

  void _handleError(String error) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null) {
      return;
    }
    final errorKind = _classifyPlaybackError(error);
    // HLS 分片短暂失败在首帧后通常可由播放器继续重试。此时保留画面并展示 buffering，
    // 不立刻进入 fatal error；但首帧前失败必须暴露为错误，避免黑屏假播放。
    final keepPlayingSurface =
        errorKind == PlayerPlaybackErrorKind.recoverableNetwork &&
        state.hasFirstFrame &&
        (state.status == PlayerPlaybackStatus.playing ||
            state.position > Duration.zero);
    _logTiming(
      keepPlayingSurface ? 'recoverable error' : 'error',
      itemId: state.currentItemId,
      source: state.currentSource,
      error: error,
      details: _timingDetails([
        'kind=${errorKind.name}',
        'hasFirstFrame=${state.hasFirstFrame}',
        'positionMs=${state.position.inMilliseconds}',
        'status=${state.status.name}',
      ]),
    );
    if (keepPlayingSurface) {
      state = state.copyWith(
        isBuffering: true,
        error: error,
        errorKind: errorKind,
      );
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.error,
      hasFirstFrame: false,
      isBuffering: false,
      error: error,
      errorKind: errorKind,
    );
  }

  PlayerPlaybackErrorKind _classifyPlaybackError(String error) {
    final normalized = error.toLowerCase();
    if (normalized.contains('tcp') ||
        normalized.contains('ffurl') ||
        normalized.contains('segment') ||
        normalized.contains('.ts') ||
        normalized.contains('connection') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return PlayerPlaybackErrorKind.recoverableNetwork;
    }
    if (normalized.contains('source') ||
        normalized.contains('resolve') ||
        normalized.contains('404') ||
        normalized.contains('403')) {
      return PlayerPlaybackErrorKind.sourceResolve;
    }
    if (normalized.contains('fatal') ||
        normalized.contains('invalid') ||
        normalized.contains('failed to open')) {
      return PlayerPlaybackErrorKind.mediaFatal;
    }
    return PlayerPlaybackErrorKind.unknown;
  }

  Duration _clampToDuration(Duration position) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    final duration = state.duration;
    if (duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }

  Future<bool> _pauseIfCurrent(int generation) async {
    await _session.pause();
    if (!_isCurrent(generation)) {
      return false;
    }
    return true;
  }

  bool _isCurrent(int generation) => generation == _generation;

  bool get _shouldPersistProgress => sessionKey.startsWith('single:');

  Future<void> _blockPlaybackForItem(
    PlayerFeedItem item, {
    required PlayerPlaybackStatus status,
    required String reason,
  }) async {
    _pauseWhenOpenCompletes = true;
    final generation = ++_generation;
    _logTiming(
      'access blocked',
      itemId: item.id,
      source: item.episode.videoSource,
      details: _timingDetails([
        'status=${status.name}',
        'reason=$reason',
        'wasCurrentItem=${state.currentItemId ?? 'null'}',
        'wasCurrentSource=${state.currentSource ?? 'null'}',
        'windowItems=${_windowItemsText()}',
      ]),
    );
    await _session.pause();
    await _releaseSessionWindowFor(reason);
    await _disposePreloads();
    if (!ref.mounted || !_isCurrent(generation)) {
      return;
    }
    state = state.copyWith(
      status: status,
      currentItemId: item.id,
      clearSource: true,
      clearError: true,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.detaching,
      clearVideoController: true,
    );
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
  }

  void _attachSessionStreams(PlayerPlaybackSession session) {
    _subscriptions = <StreamSubscription<dynamic>>[
      session.bufferingStream.listen(_handleBuffering),
      session.playingStream.listen(_handlePlaying),
      session.completedStream.listen(_handleCompleted),
      session.positionStream.listen(_handlePosition),
      session.durationStream.listen(_handleDuration),
      session.bufferedPositionStream.listen(_handleBufferedPosition),
      session.rateStream.listen(_handleRate),
      session.widthStream.listen(_handleWidth),
      session.errorStream.listen(_handleError),
    ];
  }

  Future<void> _cancelSessionStreams() async {
    final subscriptions = _subscriptions;
    _subscriptions = <StreamSubscription<dynamic>>[];
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  Future<void> _replaceCurrentSession(PreparedPlaybackSession prepared) async {
    final previousSession = _session;
    final previousSource = _currentPlaybackSource;
    final previousItemId = _currentPlaybackItemId;
    final previousHasFirstFrame = _currentPlaybackHasFirstFrame;
    final previousPosition = _currentPlaybackPosition;
    final previousDuration = _currentPlaybackDuration;
    final previousBufferedPosition = _currentPlaybackBufferedPosition;
    await _cancelSessionStreams();
    await prepared.detachFirstFrameListener();
    _session = prepared.session;
    _currentPlaybackSource = prepared.source;
    _currentPlaybackItemId = prepared.itemId;
    _attachSessionStreams(_session);
    await previousSession.pause();
    if (previousSource != null && previousItemId != null) {
      // next prepared 被接管后，旧 current 变成 previous retained。这个窗口最多保留
      // previous/current/next，目的是覆盖自然回滑，不是缓存任意历史播放页。
      _logTiming(
        'retain current before normal open',
        itemId: previousItemId,
        source: previousSource.playableSource,
        details: _timingDetails([
          'previousItemId=$previousItemId',
          'previousSource=${previousSource.playableSource}',
          'firstFrameReady=$previousHasFirstFrame',
          'positionMs=${previousPosition.inMilliseconds}',
          'durationMs=${previousDuration.inMilliseconds}',
          'bufferedMs=${previousBufferedPosition.inMilliseconds}',
          'windowItems=${_windowItemsText()}',
        ]),
      );
      await _prepareManager.retainPaused(
        PreparedPlaybackSession(
          itemId: previousItemId,
          source: previousSource,
          session: previousSession,
          kind: PreparedPlaybackSessionKind.retained,
          hasFirstFrame: previousHasFirstFrame,
          position: previousPosition,
          duration: previousDuration,
          bufferedPosition: previousBufferedPosition,
        ),
      );
      _logTiming(
        'retain current done',
        itemId: previousItemId,
        source: previousSource.playableSource,
        details: _timingDetails([
          'retainedItemId=$previousItemId',
          'windowItems=${_windowItemsText()}',
        ]),
      );
      _logTiming(
        'previous retained',
        itemId: previousItemId,
        source: previousSource.playableSource,
        details: _timingDetails([
          'firstFrameReady=$previousHasFirstFrame',
          'positionMs=${previousPosition.inMilliseconds}',
        ]),
      );
    } else {
      await previousSession.dispose();
      _logTiming(
        'dispose current session',
        details: 'reason=replace no source',
      );
    }
  }

  Future<bool> _retainCurrentBeforeNormalOpen(String nextItemId) async {
    if (_prepareManager is NoopPlayerPlaybackPrepareManager) {
      return false;
    }
    final previousSession = _session;
    final previousSource = _currentPlaybackSource;
    final previousItemId = _currentPlaybackItemId;
    if (previousSource == null ||
        previousItemId == null ||
        previousItemId == nextItemId) {
      return false;
    }

    final previousHasFirstFrame = _currentPlaybackHasFirstFrame;
    final previousPosition = _currentPlaybackPosition;
    final previousDuration = _currentPlaybackDuration;
    final previousBufferedPosition = _currentPlaybackBufferedPosition;
    _logTiming(
      'retain current before normal open',
      itemId: previousItemId,
      source: previousSource.playableSource,
      details: _timingDetails([
        'previousItemId=$previousItemId',
        'previousSource=${previousSource.playableSource}',
        'firstFrameReady=$previousHasFirstFrame',
        'positionMs=${previousPosition.inMilliseconds}',
        'durationMs=${previousDuration.inMilliseconds}',
        'bufferedMs=${previousBufferedPosition.inMilliseconds}',
        'windowItems=${_windowItemsText()}',
      ]),
    );
    // normal open fallback 也要保留 previous，因为 source resolve/open 期间最容易发生
    // 用户反向滑动。先 pause 再换新 session，可避免两个播放器同时出声。
    await previousSession.pause();
    await _cancelSessionStreams();
    await _prepareManager.retainPaused(
      PreparedPlaybackSession(
        itemId: previousItemId,
        source: previousSource,
        session: previousSession,
        kind: PreparedPlaybackSessionKind.retained,
        hasFirstFrame: previousHasFirstFrame,
        position: previousPosition,
        duration: previousDuration,
        bufferedPosition: previousBufferedPosition,
      ),
    );
    _logTiming(
      'retain current done',
      itemId: previousItemId,
      source: previousSource.playableSource,
      details: _timingDetails([
        'retainedItemId=$previousItemId',
        'windowItems=${_windowItemsText()}',
      ]),
    );

    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
    _attachSessionStreams(_session);
    state = state.copyWith(
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );
    _logTiming(
      'create current session',
      details: 'reason=normal fallback open',
    );
    return true;
  }

  Future<void> _prepareNextItem(
    PlayerFeedItem item,
    int preloadGeneration,
  ) async {
    if (!ref.mounted || _isSessionDisposed) {
      return;
    }
    if (!_preparingItemIds.add(item.id)) {
      _logTiming(
        'prepare skipped duplicate',
        itemId: item.id,
        source: item.episode.videoSource,
      );
      return;
    }
    final startedAt = DateTime.now();
    try {
      _logTiming(
        'prepare start',
        itemId: item.id,
        source: item.episode.videoSource,
      );
      // prepare 只暖下一个可播放 item，并通过 preloadGeneration 绑定当前候选窗口。
      // 用户滑走或列表刷新后，旧 prepared 必须释放，不能被后续 item 误接管。
      final prepared = await _prepareManager.prepare(
        item: item,
        sourceRepository: ref.read(playerPlaybackSourceRepositoryProvider),
      );
      if (!ref.mounted ||
          _isSessionDisposed ||
          preloadGeneration != _preloadGeneration) {
        if (prepared != null) {
          await _prepareManager.releaseItem(
            prepared.itemId,
            reason: 'stale generation',
          );
          _logTiming(
            'session window release',
            itemId: prepared.itemId,
            source: prepared.source.playableSource,
            details: 'reason=stale generation',
          );
        }
        return;
      }
      _logTiming(
        prepared == null ? 'prepare failed' : 'prepare end',
        itemId: item.id,
        source: item.episode.videoSource,
        elapsed: DateTime.now().difference(startedAt),
        details: prepared == null
            ? null
            : _timingDetails([
                'next prepared',
                'firstFrameReady=${prepared.hasFirstFrame}',
              ]),
      );
    } finally {
      _preparingItemIds.remove(item.id);
    }
  }

  Future<void> _restoreProgressIfNeeded(
    PlaybackProgress? progress,
    int generation,
  ) async {
    if (progress == null || !progress.canResume || !_shouldPersistProgress) {
      return;
    }
    await _session.seek(progress.position);
    if (!ref.mounted || !_isCurrent(generation)) {
      return;
    }
    state = state.copyWith(
      position: progress.position,
      duration: progress.duration > Duration.zero
          ? progress.duration
          : state.duration,
      bufferedPosition: state.bufferedPosition < progress.position
          ? progress.position
          : state.bufferedPosition,
    );
    _currentPlaybackPosition = progress.position;
    if (progress.duration > Duration.zero) {
      _currentPlaybackDuration = progress.duration;
    }
    if (_currentPlaybackBufferedPosition < progress.position) {
      _currentPlaybackBufferedPosition = progress.position;
    }
  }

  void _saveProgressIfNeeded({Duration? position, Duration? duration}) {
    if (!_shouldPersistProgress || state.currentItemId == null) {
      return;
    }
    final nextPosition = position ?? state.position;
    final nextDuration = duration ?? state.duration;
    if (nextPosition <= Duration.zero || nextDuration <= Duration.zero) {
      return;
    }
    unawaited(
      _progressRepository.saveProgress(
        PlaybackProgress(
          itemId: state.currentItemId!,
          position: nextPosition,
          duration: nextDuration,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  void _setPreloadState(PlaybackPreloadState preloadState) {
    _preloadStates[preloadState.itemId] = preloadState;
    if (preloadState.status == PlaybackPreloadStatus.success) {
      _preloadedItemIds.add(preloadState.itemId);
    } else {
      _preloadedItemIds.remove(preloadState.itemId);
    }
    _syncPreloadState();
  }

  void _cancelPreloadsNotIn(Set<String> allowedIds) {
    final now = DateTime.now();
    for (final entry in List<MapEntry<String, PlaybackPreloadState>>.from(
      _preloadStates.entries,
    )) {
      if (allowedIds.contains(entry.key)) {
        continue;
      }
      if (entry.value.status == PlaybackPreloadStatus.pending) {
        _preloadStates[entry.key] = entry.value.copyWith(
          status: PlaybackPreloadStatus.cancelled,
          completedAt: now,
        );
      } else {
        _preloadStates.remove(entry.key);
      }
      _preloadedItemIds.remove(entry.key);
    }
  }

  void _cancelPendingPreloads({bool syncState = true}) {
    final now = DateTime.now();
    for (final entry in List<MapEntry<String, PlaybackPreloadState>>.from(
      _preloadStates.entries,
    )) {
      if (entry.value.status == PlaybackPreloadStatus.pending) {
        _preloadStates[entry.key] = entry.value.copyWith(
          status: PlaybackPreloadStatus.cancelled,
          completedAt: now,
        );
      }
      _preloadedItemIds.remove(entry.key);
    }
    if (syncState) {
      _syncPreloadState();
    }
  }

  void _syncPreloadState() {
    if (!ref.mounted) {
      return;
    }
    final successfulIds = _preloadStates.values
        .where((entry) => entry.status == PlaybackPreloadStatus.success)
        .map((entry) => entry.itemId)
        .toList(growable: false);
    state = state.copyWith(
      preloadedItemIds: List<String>.unmodifiable(successfulIds),
      preloadStates: List<PlaybackPreloadState>.unmodifiable(
        _preloadStates.values,
      ),
    );
  }

  Future<void> _disposePreloads({bool syncState = true}) async {
    final stopwatch = Stopwatch()..start();
    // playback preload 使用独立 generation 和 preloadManager。不能和 startup preload
    // 共用 pending/release，否则首页取消首屏预热可能中断播放器页相邻预热，播放器页
    // 隐藏释放也可能误取消首页下一次启动预热。
    _preloadGeneration += 1;
    _activePreloadAllowedIds = <String>{};
    _cancelPendingPreloads(syncState: syncState);
    await _preloadManager.releasePending();
    stopwatch.stop();
    _logTiming(
      'dispose preloads',
      elapsed: stopwatch.elapsed,
      details: _timingDetails(['syncState=$syncState']),
    );
    PlayerRebuildDiagnostics.recordTiming(
      'disposePreloads',
      elapsed: stopwatch.elapsed,
      details: 'syncState=$syncState',
    );
  }

  void _clearCurrentPlaybackSnapshot() {
    _currentPlaybackHasFirstFrame = false;
    _currentPlaybackPosition = Duration.zero;
    _currentPlaybackDuration = Duration.zero;
    _currentPlaybackBufferedPosition = Duration.zero;
  }

  Future<void> _retainSessionWindowOnly(
    Set<String> allowedIds, {
    required String reason,
  }) async {
    final before = _prepareManager.windowItemIds.toSet();
    await _prepareManager.retainOnly(allowedIds);
    final after = _prepareManager.windowItemIds.toSet();
    final disposedIds = before.difference(after);
    for (final itemId in disposedIds) {
      _logTiming(
        'dispose window session',
        itemId: itemId,
        details: 'reason=$reason',
      );
    }
  }

  Future<void> _releaseSessionWindowFor(String reason) async {
    final stopwatch = Stopwatch()..start();
    final itemIds = _prepareManager.windowItemIds;
    await _prepareManager.release();
    stopwatch.stop();
    for (final itemId in itemIds) {
      _logTiming(
        'dispose window session',
        itemId: itemId,
        details: 'reason=$reason',
      );
    }
    _logTiming(
      'session window release',
      elapsed: stopwatch.elapsed,
      details: _timingDetails([
        'reason=$reason',
        'released=${itemIds.join(',')}',
      ]),
    );
    PlayerRebuildDiagnostics.recordTiming(
      'releaseSessionWindow',
      elapsed: stopwatch.elapsed,
      details: 'reason=$reason released=${itemIds.join(',')}',
    );
  }

  void _logTiming(
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
  }

  String _timingDetails(List<String> parts) {
    return _timingTrace.details(parts);
  }

  void _startPlaybackTrace(PlayerFeedItem? item) {
    _playingBeforeFirstFrameAt = null;
    _positionBeforeFirstFrameAt = null;
    _timingTrace.start(
      itemId: item?.id,
      source: item?.episode.videoSource,
      currentItemId: state.currentItemId,
      currentStatusName: state.status.name,
      generation: _generation + 1,
    );
  }

  String _windowItemsText() {
    return _prepareManager.windowItemIds.join(',');
  }

  Future<void> _disposeSessionOnly({
    Duration disposeDelay = Duration.zero,
  }) async {
    if (_isSessionDisposed) {
      return;
    }
    _isSessionDisposed = true;
    await _session.pause();
    if (disposeDelay > Duration.zero) {
      await Future<void>.delayed(disposeDelay);
    }
    await _session.dispose();
    _logTiming('dispose current session', details: 'reason=dispose session');
  }
}
