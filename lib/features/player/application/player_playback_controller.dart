import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;

import '../../../core/locale/app_locale_controller.dart';
import '../../../core/logging/app_log.dart' as developer;
import '../../../core/runtime/api_lang_provider.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../data/playback_progress_repository_provider.dart';
import '../data/drama_playback_target_repository_provider.dart';
import '../data/player_playback_source_repository_provider.dart';
import '../data/player_preload_config_provider.dart';
import '../data/player_remote_data_source_provider.dart';
import '../data/player_video_quality_preference_repository.dart';
import '../data/player_video_quality_preference_repository_provider.dart';
import '../domain/player_feed.dart';
import '../domain/drama_playback_target.dart';
import '../domain/player_content.dart';
import '../domain/player_playback_progress.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import '../domain/player_startup_quality_plan.dart';
import '../domain/player_subtitle.dart';
import '../domain/player_video_quality.dart';
import 'player_feed_controller.dart';
import 'player_playback_prepare_manager.dart';
import 'player_playback_timing_trace.dart';
import 'player_rebuild_diagnostics.dart';
import 'player_session_controller.dart';
import 'player_session_registry.dart';
import 'player_startup_preload_controller.dart';
import 'subtitle_parser.dart';

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
      final preloadConfig = ref.watch(playerPreloadConfigProvider);
      final maxWindowSessions =
          preloadConfig.effectivePreparedForwardSessionCount +
          preloadConfig.effectiveRetainedBackwardSessionCount;
      return () => PlayerPlaybackPrepareManager(
        sessionFactory: sessionFactory,
        maxWindowSessions: maxWindowSessions,
      );
    });

final playerPlaybackControllerProvider =
    NotifierProvider.family<
      PlayerPlaybackController,
      PlayerPlaybackState,
      String
    >(PlayerPlaybackController.new);

final playerWatchProgressReportIntervalProvider = Provider<Duration>(
  (_) => const Duration(seconds: 10),
);

/// 从开始解析播放源到真正收到视频首帧的最长等待时间。
///
/// 部分设备会出现音频开始播放但视频始终未渲染、且不主动报错的情况；超时后
/// 统一进入可重试错误态，避免黑屏或无限 loading。
/// iOS 的 HLS/texture 初始化在真机上可正常超过 8 秒；过早重建会丢弃即将
/// 产出的首帧并额外增加一次完整开流，因此保留更长的首次等待窗口。
Duration playerFirstFrameTimeoutFor(TargetPlatform platform) {
  return platform == TargetPlatform.iOS
      ? const Duration(seconds: 16)
      : const Duration(seconds: 8);
}

/// iOS keeps its native prepared-session window at zero to avoid stale mpv
/// textures. A hidden entry decoder would therefore be released immediately
/// and cannot accelerate the first visible frame.
bool shouldWarmForYouEntryNativeSession(TargetPlatform platform) =>
    platform == TargetPlatform.android;

final playerFirstFrameTimeoutProvider = Provider<Duration>(
  (_) => playerFirstFrameTimeoutFor(defaultTargetPlatform),
);

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
    this.hasRenderedFirstFrame = false,
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
    // ── 字幕相关字段 ─────────────────────────────
    this.availableSubtitles = const [],
    this.availableEpisodeSources = const [],
    this.currentSubtitleUrl,
    this.currentSubtitleLanguage,
    this.isSubtitleSelectionResolved = false,
    this.currentSubtitlePosition = PlayerSubtitlePosition.bottom,
    this.subtitleCues = const [],
    this.currentSubtitleText = '',
    this.availableVideoQualities = const [],
    this.selectedVideoQualityId = PlayerVideoQuality.automaticId,
    this.isVideoQualitySwitching = false,
    this.isVideoQualityLoading = false,
  });

  const PlayerPlaybackState.initial({VideoController? videoController})
    : this(
        videoController: videoController,
        status: PlayerPlaybackStatus.idle,
        hasFirstFrame: false,
        hasRenderedFirstFrame: false,
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
        // ── 字幕相关默认值 ─────────────────────────────
        availableSubtitles: const [],
        availableEpisodeSources: const [],
        currentSubtitleUrl: null,
        currentSubtitleLanguage: null,
        isSubtitleSelectionResolved: false,
        currentSubtitlePosition: PlayerSubtitlePosition.bottom,
        subtitleCues: const [],
        currentSubtitleText: '',
        availableVideoQualities: const [],
        selectedVideoQualityId: PlayerVideoQuality.automaticId,
        isVideoQualitySwitching: false,
        isVideoQualityLoading: false,
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

  /// 当前已解码的首帧是否已经实际绘制到原生 Video Surface。
  ///
  /// [hasFirstFrame] 由播放器的 width stream 推进，只能证明解码器可用；Android
  /// Surface 可能在其后才提交画面。UI 必须等此字段为 true 后再撤掉 loading，
  /// 否则会出现“loading 消失后短暂黑屏”。
  final bool hasRenderedFirstFrame;

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
  /// 当前会话独立生效；最近一次选择持久化，供后续新播放页使用。
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

  // ── 字幕相关状态 ─────────────────────────────────────

  /// 当前 episode 可用的字幕轨道列表。
  ///
  /// 为空表示无字幕可用。播放器应允许关闭字幕。
  final List<PlayerSubtitle> availableSubtitles;

  /// 当前集可用的内嵌字幕视频资源。
  final List<PlayerEpisodeSource> availableEpisodeSources;

  /// 当前选中的字幕轨道 URL。
  ///
  /// `null` 表示关闭字幕。切换字幕时更新此字段并重新加载字幕文件。
  final String? currentSubtitleUrl;

  /// 当前剧选择的字幕语言，菜单直接展示接口返回的 language。
  final String? currentSubtitleLanguage;

  /// 当前剧的字幕选择是否已确认。
  ///
  /// 外挂字幕会在首帧后异步确定默认语言；在确认前，`null` 不能被当作用户选择了
  /// “Closed”，以免入口短暂展示错误文案。
  final bool isSubtitleSelectionResolved;

  final PlayerSubtitlePosition currentSubtitlePosition;

  /// 当前已解析的字幕条目列表。
  ///
  /// 为空表示无字幕或字幕尚未加载/解析完成。
  final List<SubtitleCue> subtitleCues;

  /// 当前播放位置应显示的字幕文本。
  ///
  /// 为空字符串表示当前位置无字幕。UI 据此渲染字幕 overlay。
  final String currentSubtitleText;

  /// Current episode's manual HLS renditions. The automatic option is implicit.
  final List<PlayerVideoQuality> availableVideoQualities;

  /// The persisted preference currently applied to this source: `auto` or a
  /// [PlayerVideoQuality.id]. It is intentionally independent of the actual
  /// ABR rendition in automatic mode.
  final String selectedVideoQualityId;

  /// Lets the future settings UI display “加载中” without inferring it from
  /// general buffering, which can also be caused by normal network playback.
  final bool isVideoQualitySwitching;

  /// Master playlist rendition parsing runs alongside source opening, never
  /// from a settings-sheet tap.
  final bool isVideoQualityLoading;

  bool get isPlaying => status == PlayerPlaybackStatus.playing;
  bool get isOpening => status == PlayerPlaybackStatus.opening;
  bool get isError => status == PlayerPlaybackStatus.error;
  bool get isReady =>
      hasFirstFrame &&
      hasRenderedFirstFrame &&
      !isBuffering &&
      (status == PlayerPlaybackStatus.playing ||
          status == PlayerPlaybackStatus.paused);
  bool get isLoading =>
      currentSource != null &&
      !isError &&
      (isOpening || isBuffering || !hasFirstFrame || !hasRenderedFirstFrame);
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
    bool? hasRenderedFirstFrame,
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
    // ── 字幕相关 ─────────────────────────────────────
    List<PlayerSubtitle>? availableSubtitles,
    List<PlayerEpisodeSource>? availableEpisodeSources,
    String? currentSubtitleUrl,
    String? currentSubtitleLanguage,
    bool? isSubtitleSelectionResolved,
    PlayerSubtitlePosition? currentSubtitlePosition,
    List<SubtitleCue>? subtitleCues,
    String? currentSubtitleText,
    bool clearSubtitle = false,
    bool clearSubtitleLanguage = false,
    List<PlayerVideoQuality>? availableVideoQualities,
    String? selectedVideoQualityId,
    bool? isVideoQualitySwitching,
    bool? isVideoQualityLoading,
  }) {
    return PlayerPlaybackState(
      videoController: clearVideoController
          ? null
          : videoController ?? this.videoController,
      status: status ?? this.status,
      hasFirstFrame: clearSource ? false : hasFirstFrame ?? this.hasFirstFrame,
      hasRenderedFirstFrame: clearSource
          ? false
          : hasRenderedFirstFrame ?? this.hasRenderedFirstFrame,
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
      // ── 字幕字段 ─────────────────────────────────────
      availableSubtitles: availableSubtitles ?? this.availableSubtitles,
      availableEpisodeSources:
          availableEpisodeSources ?? this.availableEpisodeSources,
      currentSubtitleUrl: clearSubtitle
          ? null
          : (currentSubtitleUrl ?? this.currentSubtitleUrl),
      currentSubtitleLanguage: clearSubtitleLanguage
          ? null
          : currentSubtitleLanguage ?? this.currentSubtitleLanguage,
      isSubtitleSelectionResolved:
          isSubtitleSelectionResolved ?? this.isSubtitleSelectionResolved,
      currentSubtitlePosition:
          currentSubtitlePosition ?? this.currentSubtitlePosition,
      subtitleCues: subtitleCues ?? this.subtitleCues,
      currentSubtitleText: currentSubtitleText ?? this.currentSubtitleText,
      availableVideoQualities:
          availableVideoQualities ?? this.availableVideoQualities,
      selectedVideoQualityId:
          selectedVideoQualityId ?? this.selectedVideoQualityId,
      isVideoQualitySwitching:
          isVideoQualitySwitching ?? this.isVideoQualitySwitching,
      isVideoQualityLoading:
          isVideoQualityLoading ?? this.isVideoQualityLoading,
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
  static const _restoreFloorTimeout = Duration(seconds: 12);
  static const _firstFrameProgressProbeDelay = Duration(milliseconds: 800);
  // 已确认音频时钟/续播位置在推进但没有 video width，说明不是单纯的网络首段
  // 等待。此时 1.4 秒已足够区分正常 decoder 初始化与 Android HLS 卡住；更早重开
  // 可直接复用刚下载的 playlist/关键段，避免旧的 2.8 秒空转。
  static const _firstFrameVideoRecoveryDelay = Duration(milliseconds: 1400);
  // 压力模式只能在连续稳定播放后恢复。不要用固定倒计时恢复，否则设备正好仍然
  // 紧张时会重新引入第三个 MediaCodec session。
  static const _decoderPressureStablePlayback = Duration(seconds: 15);
  // 首帧后不必再等待 750ms 才开始下一集预热；350ms 已能避开首段最敏感的
  // buffer 窗口，同时减少用户快速滑到下一集时完全冷开的概率。低端档本身禁用
  // 相邻预热，因此不会额外增加 MediaCodec 压力。
  static const _preloadReadinessAdvance = Duration(milliseconds: 350);
  static const _resumeOpenStartMinPosition = Duration(seconds: 10);
  static const _localResumeReadBudget = Duration(milliseconds: 180);

  String? _preferredSubtitleLanguage;
  bool _externalSubtitlesClosed = false;
  PlayerFeedItem? _currentOriginalItem;
  Timer? _firstFrameProgressProbeTimer;
  Timer? _firstFrameVideoRecoveryTimer;
  Timer? _firstFrameTimeoutTimer;

  /// Raw confirmed media samples; null ends a continuous watch segment.
  void Function(Duration? position, int generation)? onEffectiveWatchPosition;
  int _effectiveWatchGeneration = 0;
  int _effectiveWatchSeekDepth = 0;

  void _emitEffectiveWatchPosition(Duration? position) {
    try {
      onEffectiveWatchPosition?.call(position, _effectiveWatchGeneration);
    } catch (error, stackTrace) {
      developer.log(
        'Effective watch observer failed; playback continues',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _seekWithWatchBoundary(Duration target) async {
    ++_effectiveWatchGeneration;
    ++_effectiveWatchSeekDepth;
    _emitEffectiveWatchPosition(null);
    try {
      await _session.seek(target);
    } finally {
      --_effectiveWatchSeekDepth;
      ++_effectiveWatchGeneration;
    }
  }

  Timer? _watchProgressReportTimer;
  DateTime? _watchProgressReportTimerStartedAt;
  Duration? _watchProgressReportRemaining;
  PlayerFeedItem? _visibilitySuspendedItem;
  PlayerFeedItem? _pendingSubtitleLoadItem;

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

  static bool get _shouldDeferPreloadUntilFirstFrame {
    if (kIsWeb) {
      return false;
    }
    final WidgetsBinding binding;
    try {
      binding = WidgetsBinding.instance;
    } catch (_) {
      return true;
    }
    return !binding.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    );
  }

  final String sessionKey;
  late PlayerPlaybackSession _session;
  late final PlayerPlaybackPreloadManager _preloadManager;
  late final PlayerPlaybackPreloadManager _predictivePreloadManager;
  late final PlayerPlaybackPrepareManager _prepareManager;
  late final PlaybackProgressRepository _progressRepository;
  late final DramaPlaybackTargetRepository _dramaPlaybackTargetRepository;
  late final PlayerVideoQualityPreferenceRepository
  _videoQualityPreferenceRepository;
  Future<void>? _videoQualityPreferenceReady;
  bool _hasLoadedVideoQualityPreference = false;
  String _preferredVideoQualityId = PlayerVideoQuality.automaticId;
  PlayerFeedItem? _currentQualityMasterItem;
  var _subscriptions = <StreamSubscription<dynamic>>[];
  final _preloadedItemIds = <String>{};
  final _predictivePreloadedItemIds = <String>{};
  final _preloadStates = <String, PlaybackPreloadState>{};
  final _preparingItemIds = <String>{};
  var _activePreloadAllowedIds = <String>{};
  List<PlayerFeedItem>? _deferredPreloadItems;
  int? _deferredPreloadIndex;
  PlaybackProgress? _pendingResumeProgress;
  bool _pendingResumeProgressRequiresSeekAfterOpen = false;
  bool _lastResumeProgressRequiresSeekAfterOpen = false;
  bool _lastResumeProgressWasPending = false;
  int _generation = 0;
  // 画质和内嵌语言都会重开当前 source。它们可能由连续点击同时触发，不能让较早
  // 的异步请求在较晚请求完成后再写回旧 source/state。
  int _sourceSwitchOperation = 0;
  int _preloadGeneration = 0;
  int _predictivePreloadGeneration = 0;
  String? _predictivePreloadItemId;
  int _visibilityDetachEpoch = 0;
  bool _pauseWhenOpenCompletes = false;
  bool _isPlaybackVisible = true;
  bool _isSuspendedForCompetingPlayer = false;
  bool _isRetainedForCompetingPlayer = false;
  Future<void> _competingPlayerTransition = Future<void>.value();
  // next 的真实首帧预热或接管会短时间内与 current/previous 并存。部分原生播放器
  // 会把正在播放的 current 异常切成 paused（并非一次新的 playItem/open）。只在这个
  // 很小的危险窗口内恢复 current，避免用户看到播几秒又从头开始，也不能把用户主动
  // 暂停或退后台当成异常恢复。
  DateTime? _unexpectedPauseRecoveryDeadline;
  bool _userPauseRequested = false;
  bool _unexpectedPauseRecoveryInFlight = false;
  bool _preparedTakeoverPlayPending = false;
  bool _preparedTakeoverPausedWhileOpening = false;
  bool _positionRollbackRecoveryInFlight = false;
  String? _accessOverlayPausedItemId;
  bool _isSessionDisposed = false;
  bool _wasPlayingBeforeSeek = false;
  bool _ignoreNextCompleted = false;
  Duration? _lastPositionUpdate;
  Duration? _restoreFloorPosition;
  int _restoreFloorGeneration = 0;
  Timer? _restoreFloorTimer;
  bool _resumeGuardRepairing = false;
  int _resumeGuardRepairAttempts = 0;
  String? _lastAppliedResumeItemId;
  Duration? _lastAppliedResumePosition;
  int _lastAppliedResumeGeneration = -1;
  DateTime? _lastProgressSaveAt;
  String? _lastSavedProgressItemId;
  Duration? _lastSavedProgressPosition;
  Duration? _lastSavedProgressDuration;
  String? _lastPauseReportItemId;
  int? _lastPauseReportWatchSecond;
  int? _lastStartReportGeneration;
  String? _lastStartReportItemId;
  String? _lastStartReportSource;
  bool _watchProgressReportInFlight = false;
  late final _timingTrace = PlayerPlaybackTimingTrace(sessionKey: sessionKey);
  final _playingBeforeFirstFrameLoggedItemIds = <String>{};
  final _positionBeforeFirstFrameLoggedItemIds = <String>{};
  final _firstPositionLoggedItemIds = <String>{};
  final _surfaceBeforeFirstFrameLoggedItemIds = <String>{};
  DateTime? _surfaceFirstFrameRenderWaitStartedAt;
  String? _surfaceFirstFrameRenderWaitItemId;
  VideoController? _surfaceFirstFrameRenderWaitController;
  DateTime? _playingBeforeFirstFrameAt;
  DateTime? _positionBeforeFirstFrameAt;
  String? _currentPlaybackItemId;
  String? _forYouEntryWarmItemId;
  Timer? _forYouEntryWarmReleaseTimer;
  PlaybackSource? _currentPlaybackSource;
  bool _currentPlaybackHasFirstFrame = false;
  bool _decoderPressureActive = false;
  DateTime? _decoderPressureStableSince;
  String? _decoderPressureReason;
  bool _firstFrameVideoRecoveryAttempted = false;
  String? _firstFrameAutoRetryItemId;
  Future<void> _forYouRecoveryOperation = Future<void>.value();
  Duration _currentPlaybackPosition = Duration.zero;
  Duration _lastNativePlaybackPosition = Duration.zero;
  Duration _currentPlaybackDuration = Duration.zero;
  Duration _currentPlaybackBufferedPosition = Duration.zero;
  Duration? _preloadReadinessStartPosition;
  bool _preloadReadinessReached = false;

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

  /// 不能把 width stream 当作画面已经上屏：该事件由 Video widget 在原生 Surface
  /// 实际绘制首帧后调用，用于安全地撤掉 loading。
  void markVideoSurfaceFirstFrameRendered({
    required String itemId,
    required VideoController videoController,
    String? source,
  }) {
    if (!ref.mounted ||
        state.currentItemId != itemId ||
        state.videoController != videoController ||
        state.currentSource == null ||
        state.hasRenderedFirstFrame) {
      return;
    }
    final now = DateTime.now();
    final startedAt = _surfaceFirstFrameRenderWaitItemId == itemId
        ? _surfaceFirstFrameRenderWaitStartedAt
        : null;
    _logTiming(
      'video surface first frame rendered',
      itemId: itemId,
      source: source ?? state.currentSource,
      details: _timingDetails([
        if (startedAt != null)
          'renderDelayAfterSurfaceMountedMs=${now.difference(startedAt).inMilliseconds}',
      ]),
    );
    state = state.copyWith(hasRenderedFirstFrame: true);
  }

  /// 收到 width 首帧后立即等待 native Surface 的渲染确认。
  ///
  /// 不能放在 Video widget 的下一次 build：在真机上该 rebuild 会额外晚 300–400ms，
  /// 造成 loading 与实际画面之间多一段不必要的空档。
  void _waitForVideoSurfaceFirstFrameRendered() {
    final itemId = state.currentItemId;
    final source = state.currentSource;
    final controller = state.videoController;
    if (itemId == null || source == null || controller == null) {
      return;
    }
    if (_surfaceFirstFrameRenderWaitItemId == itemId &&
        identical(_surfaceFirstFrameRenderWaitController, controller)) {
      return;
    }
    _surfaceFirstFrameRenderWaitItemId = itemId;
    _surfaceFirstFrameRenderWaitController = controller;
    _surfaceFirstFrameRenderWaitStartedAt = DateTime.now();
    _logTiming(
      'video surface first-frame render wait start',
      itemId: itemId,
      source: source,
    );
    final generation = _generation;
    unawaited(
      _awaitVideoSurfaceFirstFrameRendered(
        generation: generation,
        itemId: itemId,
        source: source,
        videoController: controller,
      ),
    );
  }

  Future<void> _awaitVideoSurfaceFirstFrameRendered({
    required int generation,
    required String itemId,
    required String source,
    required VideoController videoController,
  }) async {
    try {
      final platformController = await videoController.platform.future;
      await platformController.waitUntilFirstFrameRendered;
    } catch (_) {
      // 平台视频输出不可用时仍由原有首帧超时/错误处理兜底，不能在这里吞掉播放器错误。
      return;
    }
    if (!ref.mounted ||
        generation != _generation ||
        state.currentItemId != itemId ||
        !identical(state.videoController, videoController)) {
      return;
    }
    markVideoSurfaceFirstFrameRendered(
      itemId: itemId,
      source: source,
      videoController: videoController,
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

  /// 设置待恢复的播放进度（从播放历史进入时使用）。
  void setPendingResumeProgress(
    PlaybackProgress? progress, {
    bool requireSeekAfterOpen = false,
  }) {
    if (progress != null && _isStaleResumeProgress(progress)) {
      _logTiming(
        'pending resume progress skipped stale',
        itemId: progress.itemId,
        source: state.currentSource,
        details: _timingDetails([
          'currentMs=${state.position.inMilliseconds}',
          'resumeMs=${progress.position.inMilliseconds}',
        ]),
      );
      return;
    }
    _pendingResumeProgress = progress;
    _pendingResumeProgressRequiresSeekAfterOpen =
        progress != null && requireSeekAfterOpen;
  }

  /// 对当前正在播放的 item 立即应用恢复进度。
  ///
  /// 远程观看进度可能晚于首播链路返回；这时不能重新 open source，只需要在
  /// 当前 generation 上补一次 seek，并同步进度条/字幕位置。
  Future<void> restoreCurrentProgress(PlaybackProgress progress) async {
    if (_isSessionDisposed ||
        state.currentItemId == null ||
        state.currentItemId != progress.itemId ||
        state.currentSource == null) {
      setPendingResumeProgress(progress);
      return;
    }
    final normalized = _normalizeResumeProgress(
      progress,
      state.duration > Duration.zero ? state.duration : null,
    );
    if (normalized == null) {
      return;
    }
    await _restoreProgressIfNeeded(normalized, _generation);
  }

  /// 应用标准播放页回传的权威进度，并保证 For You 画面重新挂载后自动播放。
  Future<void> synchronizeExternalProgress({
    required PlayerFeedItem item,
    required Duration position,
    required Duration duration,
  }) async {
    if (_isSessionDisposed) {
      return;
    }
    final effectiveDuration = duration > Duration.zero
        ? duration
        : item.episode.duration ?? Duration.zero;
    final maxPosition = effectiveDuration > Duration.zero
        ? effectiveDuration
        : position;
    final target = position < Duration.zero
        ? Duration.zero
        : position > maxPosition
        ? maxPosition
        : position;
    final usesCurrentSource =
        state.currentItemId == item.id &&
        state.currentSource != null &&
        _usesCurrentMediaSource(item);

    if (usesCurrentSource) {
      _visibilityDetachEpoch += 1;
      _pauseWhenOpenCompletes = false;
      _accessOverlayPausedItemId = null;
      ++_generation;
      await _seekWithWatchBoundary(target);
      if (!ref.mounted) {
        return;
      }
      _currentPlaybackPosition = target;
      if (effectiveDuration > Duration.zero) {
        _currentPlaybackDuration = effectiveDuration;
      }
      await _session.play();
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.playing,
        position: target,
        duration: effectiveDuration > Duration.zero
            ? effectiveDuration
            : state.duration,
        hasEnded: false,
        isBuffering: !state.hasFirstFrame,
        videoController: _session.videoController,
        surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
      );
      _lastAppliedResumeGeneration = _generation;
      _lastAppliedResumeItemId = item.id;
      _lastAppliedResumePosition = target;
      _resumeGuardRepairAttempts = 0;
      _armRestoreFloor(target, _generation);
      unawaited(_confirmRestoreSeek(target, _generation));
      _syncWatchProgressReportTimer();
      return;
    }

    if (target > Duration.zero && effectiveDuration > Duration.zero) {
      _pendingResumeProgress = PlaybackProgress(
        itemId: item.id,
        position: target,
        duration: effectiveDuration,
        updatedAt: DateTime.now(),
      );
    } else {
      _pendingResumeProgress = null;
    }
    // 外部 handoff 是权威状态，不能被 playItem 的 500ms UI 防抖误吞。
    _lastPlayItemRequest = null;
    await playItem(item);
  }

  static const _ratePreferenceKey = 'player.playback_rate.preference';
  static const _supportedRates = [0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
  double _preferredPlaybackRate = 1.0;
  late Future<void> _ratePreferenceReady;

  bool get _isForYouSession =>
      sessionKey == PlayerPlaybackSessionKeys.forYouTab;

  Future<void> _loadPlaybackRate() async {
    if (_isForYouSession) {
      // For You always plays at normal speed. Its controller is kept alive
      // across tab switches, so it must neither read nor modify the regular
      // player's persisted preference.
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble(_ratePreferenceKey);
      if (_supportedRates.contains(rate)) _preferredPlaybackRate = rate!;
    } catch (_) {
      // Local storage failures must not prevent playback.
    }
    if (ref.mounted && !_isSessionDisposed) {
      state = state.copyWith(playbackRate: _preferredPlaybackRate);
    }
  }

  @override
  PlayerPlaybackState build() {
    _ratePreferenceReady = _loadPlaybackRate();
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _preloadManager = ref.read(playerPlaybackPreloadManagerProvider);
    _predictivePreloadManager = ref.read(
      forYouPredictivePlaybackPreloadManagerProvider,
    );
    _prepareManager = ref.read(playerPlaybackPrepareManagerFactoryProvider)();
    _prepareManager.timingLogger = _handlePrepareTiming;
    _progressRepository = ref.read(playbackProgressRepositoryProvider);
    _dramaPlaybackTargetRepository = ref.read(
      dramaPlaybackTargetRepositoryProvider,
    );
    _videoQualityPreferenceRepository = ref.read(
      playerVideoQualityPreferenceRepositoryProvider,
    );
    // For You owns an automatic rendition policy. It must not inherit the
    // ordinary player's persisted manual quality while its persistent tab
    // session is recreated after a handoff.
    if (!_isForYouSession) {
      // Populate the in-memory preference while Home is preparing entry media.
      // A launch plan can still bypass this wait when it is already available.
      unawaited(initializeVideoQualityPreference());
    }
    _attachSessionStreams(_session);
    // 真机日志显示 iOS 在第三次切集后，previous/current/next 三个原生会话同时
    // 存在时可能仍持续拉取分片、position 也继续推进，但新 texture 不再出画面。
    // 因此 iOS 固定为 current + next 两路。两台真机均已复现：即便先连续稳定
    // 播放，再恢复 previous/current/next 三路，下一次 prepared takeover 仍可能让
    // 新 Surface 变成 0x0。回滑改由 HLS 本地缓存快速重开，不保留第三个原生会话。
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _decoderPressureActive = true;
      _decoderPressureReason = 'iOS permanent two-session native cap';
      _logTiming(
        'iOS two-session window enabled',
        details: _timingDetails([
          'reason=permanent_native_surface_cap',
          'maxNativeSessions=2',
        ]),
      );
    }
    _logTiming('create current session', details: 'reason=build');
    ref.onDispose(() {
      // provider dispose 是最后一道兜底：必须同时释放流、HTTP 预加载、prepared
      // window 和当前播放器。这里不依赖 UI dispose，因为 tab、route、后台切换的
      // 生命周期触发顺序并不总是稳定。
      unawaited(_cancelSessionStreams());
      _restoreFloorTimer?.cancel();
      _firstFrameProgressProbeTimer?.cancel();
      _firstFrameVideoRecoveryTimer?.cancel();
      _firstFrameTimeoutTimer?.cancel();
      _forYouEntryWarmReleaseTimer?.cancel();
      _stopWatchProgressReportTimer();
      unawaited(_disposePreloads(syncState: false));
      unawaited(_predictivePreloadManager.releasePending());
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

  /// Called when the future quality settings surface is first needed.  Delaying
  /// this read keeps background player instances from unexpectedly changing a
  /// source before their settings UI has attached.
  Future<void> initializeVideoQualityPreference() {
    if (_isForYouSession) {
      _hasLoadedVideoQualityPreference = true;
      _preferredVideoQualityId = PlayerVideoQuality.automaticId;
      if (ref.mounted && state.currentItemId == null) {
        state = state.copyWith(
          selectedVideoQualityId: PlayerVideoQuality.automaticId,
        );
      }
      return _videoQualityPreferenceReady ??= Future<void>.value();
    }
    if (_hasLoadedVideoQualityPreference) {
      return _videoQualityPreferenceReady ?? Future<void>.value();
    }
    _hasLoadedVideoQualityPreference = true;
    return _videoQualityPreferenceReady = _restoreVideoQualityPreference();
  }

  Future<void> _restoreVideoQualityPreference() async {
    _preferredVideoQualityId = await _videoQualityPreferenceRepository.read();
    // Once an episode is opening/playing, its selected id represents the
    // effective rendition (which may be a non-member fallback from a stored
    // 1080p preference). Do not let a late preference read repaint it as the
    // unavailable historical preference.
    if (ref.mounted && state.currentItemId == null) {
      state = state.copyWith(selectedVideoQualityId: _preferredVideoQualityId);
    }
  }

  PlayerStartupQualityPlan? _startupQualityPlanFor(PlayerFeedItem item) {
    final plan = ref.read(playerStartupPreloadControllerProvider).qualityPlan;
    return plan != null && plan.matches(item) ? plan : null;
  }

  /// Loads the current episode's HLS renditions without preheating any media
  /// playlist or segment.  The future quality UI can call this as it opens.
  Future<List<PlayerVideoQuality>> loadAvailableVideoQualities() async {
    await initializeVideoQualityPreference();
    final item = _currentQualityMasterItem ?? _currentOriginalItem;
    final sourceUrl = item?.episode.videoSource;
    if (item == null || sourceUrl == null || sourceUrl.isEmpty) {
      return const [];
    }
    if (state.availableVideoQualities.isNotEmpty) {
      return state.availableVideoQualities;
    }
    // Kept as an explicit recovery API for a failed background inspection.
    // Normal settings UI only reads state and never calls this method.
    return _inspectVideoQualities(item, sourceUrl);
  }

  Future<List<PlayerVideoQuality>> _inspectVideoQualities(
    PlayerFeedItem item,
    String sourceUrl,
  ) async {
    try {
      final qualities = await ref
          .read(hlsPlaylistPreloaderProvider)
          .inspectQualities(sourceUrl);
      if (!ref.mounted || state.currentItemId != item.id) {
        return qualities;
      }
      // A manual preference can fall back on a neighbouring episode. Keep the
      // preference for subsequent episodes, but show the rendition actually
      // in use as selected in this episode's quality sheet.
      final effectiveQuality =
          _preferredVideoQualityId == PlayerVideoQuality.automaticId
          ? null
          : _fallbackQualityFor(
              qualities,
              _preferredVideoQualityId,
              isMember: ref.read(entitlementControllerProvider).isMember,
            );
      state = state.copyWith(
        availableVideoQualities: qualities,
        selectedVideoQualityId:
            _preferredVideoQualityId == PlayerVideoQuality.automaticId
            ? PlayerVideoQuality.automaticId
            : effectiveQuality?.id ?? _preferredVideoQualityId,
        isVideoQualityLoading: false,
      );
      return qualities;
    } catch (error) {
      _logTiming(
        'video quality inspect failed',
        itemId: item.id,
        source: sourceUrl,
        error: error,
      );
      if (ref.mounted && state.currentItemId == item.id) {
        state = state.copyWith(isVideoQualityLoading: false);
      }
      return const [];
    }
  }

  /// Changes to one concrete rendition while retaining position and play state.
  ///
  /// A non-member still receives 1080p in [availableVideoQualities]; this
  /// method returns [PlayerVideoQualitySelectionResult.requiresMembership] so
  /// the UI can show its distinct visual treatment and route to membership.
  Future<PlayerVideoQualitySelectionResult> selectVideoQuality(
    String qualityId,
  ) async {
    if (_isForYouSession) {
      // For You has no manual quality setting. Keeping this defensive guard
      // prevents a future UI caller from persisting a choice into the regular
      // player's preference or rebuilding the feed's active decoder.
      return PlayerVideoQualitySelectionResult.unavailable;
    }
    await _releaseRetainedForYouSession('ordinary player quality changed');
    final operation = ++_sourceSwitchOperation;
    await initializeVideoQualityPreference();
    if (!_isCurrentSourceSwitch(operation)) {
      return PlayerVideoQualitySelectionResult.switched;
    }
    final masterItem = _currentQualityMasterItem ?? _currentOriginalItem;
    if (masterItem == null || state.currentItemId != masterItem.id) {
      return PlayerVideoQualitySelectionResult.unavailable;
    }
    final qualities = state.availableVideoQualities.isEmpty
        ? await loadAvailableVideoQualities()
        : state.availableVideoQualities;
    if (!_isCurrentSourceSwitch(operation)) {
      return PlayerVideoQualitySelectionResult.switched;
    }
    final selected = qualityId == PlayerVideoQuality.automaticId
        ? null
        : _qualityById(qualities, qualityId);
    if (qualityId != PlayerVideoQuality.automaticId && selected == null) {
      return PlayerVideoQualitySelectionResult.unavailable;
    }
    final onlyRendition = qualities.length <= 1;
    if (selected != null &&
        selected.isMemberOnly &&
        !onlyRendition &&
        !ref.read(entitlementControllerProvider).isMember) {
      return PlayerVideoQualitySelectionResult.requiresMembership;
    }
    if (state.selectedVideoQualityId == qualityId &&
        !state.isVideoQualitySwitching) {
      return PlayerVideoQualitySelectionResult.switched;
    }

    final oldQualityId = state.selectedVideoQualityId;
    final oldPosition = state.position;
    final oldDuration = state.duration;
    final wasPlaying = state.isPlaying;
    final targetUrl = selected?.playlistUrl ?? masterItem.episode.videoSource;
    if (targetUrl == null || targetUrl.isEmpty) {
      return PlayerVideoQualitySelectionResult.unavailable;
    }
    final targetItem = masterItem.copyWith(
      episode: masterItem.episode.copyWith(videoUrl: targetUrl),
    );
    state = state.copyWith(
      isVideoQualitySwitching: true,
      selectedVideoQualityId: qualityId,
    );
    _pendingResumeProgress = PlaybackProgress(
      itemId: targetItem.id,
      position: oldPosition,
      duration: oldDuration,
      updatedAt: DateTime.now(),
    );
    _pendingResumeProgressRequiresSeekAfterOpen = true;
    _pauseWhenOpenCompletes = !wasPlaying;
    try {
      _preferredVideoQualityId = qualityId;
      // Startup and in-player preloads deliberately use separate managers.
      // Drop a Home-created Auto rendition before opening this manual choice;
      // otherwise a 540p startup request can keep consuming bandwidth while
      // the player has already moved to (for example) 720p.
      await ref
          .read(playerStartupPreloadControllerProvider.notifier)
          .cancel(reason: 'manual video quality changed', syncState: false);
      if (!_isCurrentSourceSwitch(operation)) {
        return PlayerVideoQualitySelectionResult.switched;
      }
      await _disposePreloads();
      if (!_isCurrentSourceSwitch(operation)) {
        return PlayerVideoQualitySelectionResult.switched;
      }
      await _releaseSessionWindowFor('video quality changed');
      if (!_isCurrentSourceSwitch(operation)) {
        return PlayerVideoQualitySelectionResult.switched;
      }
      _lastPlayItemRequest = null;
      await playItem(targetItem, forceReopen: true, rethrowOnFailure: true);
      if (!_isCurrentSourceSwitch(operation)) {
        return PlayerVideoQualitySelectionResult.switched;
      }
      if (!ref.mounted) return PlayerVideoQualitySelectionResult.failed;
      _preferredVideoQualityId = qualityId;
      unawaited(_videoQualityPreferenceRepository.save(qualityId));
      state = state.copyWith(
        selectedVideoQualityId: qualityId,
        isVideoQualitySwitching: false,
      );
      return PlayerVideoQualitySelectionResult.switched;
    } catch (error) {
      if (!_isCurrentSourceSwitch(operation)) {
        return PlayerVideoQualitySelectionResult.switched;
      }
      _preferredVideoQualityId = oldQualityId;
      _logTiming(
        'video quality switch failed; restoring old source',
        itemId: masterItem.id,
        source: targetUrl,
        error: error,
      );
      _pendingResumeProgress = PlaybackProgress(
        itemId: masterItem.id,
        position: oldPosition,
        duration: oldDuration,
        updatedAt: DateTime.now(),
      );
      _pendingResumeProgressRequiresSeekAfterOpen = true;
      _pauseWhenOpenCompletes = !wasPlaying;
      _lastPlayItemRequest = null;
      try {
        await playItem(masterItem, forceReopen: true);
      } catch (_) {
        // playItem records the error state; there is no further safe fallback.
      }
      if (_isCurrentSourceSwitch(operation)) {
        state = state.copyWith(
          selectedVideoQualityId: oldQualityId,
          isVideoQualitySwitching: false,
        );
      }
      return PlayerVideoQualitySelectionResult.failed;
    }
  }

  PlayerVideoQuality? _qualityById(
    List<PlayerVideoQuality> qualities,
    String id,
  ) {
    for (final quality in qualities) {
      if (quality.id == id) return quality;
    }
    return null;
  }

  /// Resolves the preference for an item before issuing an HLS preheat.  This
  /// is intentionally shared by all controller-owned preload paths: a manual
  /// 720p preference must never cause the preloader to fetch its old default
  /// (lowest bitrate) rendition first.
  Future<PlayerFeedItem> _itemUsingPreferredVideoQuality(
    PlayerFeedItem item,
  ) async {
    if (_isForYouSession) return item;
    if (!_hasLoadedVideoQualityPreference) return item;
    await _videoQualityPreferenceReady;
    final preferredId = _preferredVideoQualityId;
    final sourceUrl = item.episode.videoSource;
    if (preferredId == PlayerVideoQuality.automaticId ||
        sourceUrl == null ||
        sourceUrl.isEmpty) {
      return item;
    }
    try {
      final qualities = await ref
          .read(hlsPlaylistPreloaderProvider)
          .inspectQualities(sourceUrl);
      final selected = _fallbackQualityFor(
        qualities,
        preferredId,
        isMember: ref.read(entitlementControllerProvider).isMember,
      );
      if (selected == null) return item;
      return item.copyWith(
        episode: item.episode.copyWith(videoUrl: selected.playlistUrl),
      );
    } catch (error) {
      _logTiming(
        'quality-aware preload source fallback to master',
        itemId: item.id,
        source: sourceUrl,
        error: error,
      );
      return item;
    }
  }

  PlayerVideoQuality? _fallbackQualityFor(
    List<PlayerVideoQuality> qualities,
    String preferredId, {
    required bool isMember,
  }) {
    if (qualities.isEmpty) return null;
    final allowed = qualities.length == 1 || isMember
        ? qualities
        : qualities.where((quality) => !quality.isMemberOnly).toList();
    if (allowed.isEmpty) return qualities.first;
    final exact = _qualityById(allowed, preferredId);
    if (exact != null) return exact;
    final preferredHeight = int.tryParse(
      RegExp(r'^(\d+)p$').firstMatch(preferredId)?.group(1) ?? '',
    );
    if (preferredHeight == null) return allowed.last;
    final lower =
        allowed.where((quality) => quality.height < preferredHeight).toList()
          ..sort((left, right) => right.height.compareTo(left.height));
    if (lower.isNotEmpty) return lower.first;
    final higher =
        allowed.where((quality) => quality.height > preferredHeight).toList()
          ..sort((left, right) => left.height.compareTo(right.height));
    return higher.isEmpty ? allowed.first : higher.first;
  }

  /// Automatic playback starts from a single conservative 540p-or-lower
  /// rendition. This makes HLS preload, prepared session and real playback
  /// consume identical segments; manual quality selection remains unrestricted.
  int? _automaticVideoHeightCap() {
    return _preferredVideoQualityId == PlayerVideoQuality.automaticId
        ? 540
        : null;
  }

  /// 防止短时间内重复调用 playItem 导致多次 open
  PlayerFeedItem? _lastPlayItemRequest;
  DateTime _lastPlayItemTime = DateTime.now();

  /// 在 For You Tab 仍隐藏时，为首条可播放视频建立一个静音 prepared session。
  ///
  /// 仅允许用于稳定的 For You session，且不修改当前播放状态、不上报观看进度。
  /// 等用户真正进入 Tab 时，[playItem] 会接管该 session；这才覆盖了仅预取推荐
  /// 列表无法覆盖的 HLS 首帧下载与解码等待。
  Future<void> warmUpForYouEntry(PlayerFeedItem item) async {
    if (sessionKey != PlayerPlaybackSessionKeys.forYouTab ||
        _isSessionDisposed ||
        state.currentItemId != null ||
        item.mode != PlayerFeedMode.forYou ||
        item.episode.isLocked ||
        item.episode.isUnavailable ||
        item.episode.videoSource == null) {
      return;
    }
    // 首页隐藏态预热也是真实 media session；必须登记，普通播放器进入时才能暂停它，
    // 而不是让它在后台继续下载/解码并抢占首播资源。
    ref.read(playerSessionRegistryProvider.notifier).register(sessionKey);
    final startedAt = DateTime.now();
    _forYouEntryWarmReleaseTimer?.cancel();
    _forYouEntryWarmItemId = item.id;
    _logTiming(
      'for you initial prepare start',
      itemId: item.id,
      source: item.episode.videoSource,
    );
    final prepared = await _prepareManager.prepare(
      item: item,
      sourceRepository: ref.read(playerPlaybackSourceRepositoryProvider),
      maxVideoHeight: _automaticVideoHeightCap(),
      // 首页首条的用户进入窗口比相邻滑动更长。仅这个隐藏态 session 继续静音
      // 解码最多 8 秒，避免 4 秒时暂停后又在用户点入时重新恢复解码。
      warmUpTimeout: const Duration(seconds: 8),
    );
    if (!ref.mounted || _isSessionDisposed || state.currentItemId != null) {
      if (prepared != null) {
        await _prepareManager.releaseItem(
          prepared.itemId,
          reason: 'for you initial prepare no longer needed',
        );
      }
      if (_forYouEntryWarmItemId == item.id) {
        _forYouEntryWarmItemId = null;
      }
      return;
    }
    _logTiming(
      prepared == null
          ? 'for you initial prepare failed'
          : 'for you initial prepare end',
      itemId: item.id,
      source: item.episode.videoSource,
      elapsed: DateTime.now().difference(startedAt),
      details: prepared == null
          ? null
          : 'firstFrameReady=${prepared.hasFirstFrame}',
    );
    if (prepared != null) {
      // 首页停留很久时不能把一个隐藏 decoder 永久留在窗口里。超过短暂的用户
      // 决策窗口仍未进入 For You，就释放它；下次进 Tab 再正常打开即可。
      _forYouEntryWarmReleaseTimer = Timer(const Duration(seconds: 12), () {
        if (!ref.mounted ||
            _isSessionDisposed ||
            _forYouEntryWarmItemId != item.id ||
            state.currentItemId != null) {
          return;
        }
        _forYouEntryWarmItemId = null;
        unawaited(
          _prepareManager.releaseItem(
            item.id,
            reason: 'for you initial prepare expired',
          ),
        );
      });
    }
  }

  Future<void> playItem(
    PlayerFeedItem? item, {
    bool resumeIfCurrentSource = false,
    bool forceReopen = false,
    bool rethrowOnFailure = false,
  }) async {
    if (_isSessionDisposed) {
      return;
    }

    if (!_isForYouSession &&
        item != null &&
        state.currentItemId != null &&
        state.currentItemId != item.id) {
      await _releaseRetainedForYouSession('ordinary player item changed');
    }

    PlayerStartupQualityPlan? startupQualityPlan;
    if (item != null) {
      _visibilitySuspendedItem = null;
      if (_currentQualityMasterItem?.id != item.id) {
        _currentQualityMasterItem = item;
      }
      final previousLanguage = _preferredSubtitleLanguage;
      _currentOriginalItem = item;
      item = _itemUsingPreferredEmbeddedSource(item);
      await _ratePreferenceReady;
      if (!ref.mounted || _isSessionDisposed) return;
      state = state.copyWith(playbackRate: _preferredPlaybackRate);
      startupQualityPlan = _startupQualityPlanFor(item);
      startupQualityPlan ??= await ref
          .read(playerStartupPreloadControllerProvider.notifier)
          .qualityPlanFor(item);
      if (startupQualityPlan != null && !startupQualityPlan.matches(item)) {
        startupQualityPlan = null;
      }
      if (startupQualityPlan != null) {
        // Home has already chosen and warmed this exact rendition. Reuse it
        // directly instead of parsing the master playlist a second time.
        _preferredVideoQualityId = startupQualityPlan.preferenceId;
        item = startupQualityPlan.applyTo(item);
      } else {
        // Direct/deep-link entry has no Home plan. Resolve the saved choice
        // before opening so it never flashes Auto then switches quality.
        await initializeVideoQualityPreference();
        if (!ref.mounted || _isSessionDisposed) return;
        item = await _itemUsingPreferredVideoQuality(item);
      }
      if (previousLanguage != null &&
          _preferredSubtitleLanguage != previousLanguage) {
        await _disposePreloads();
        await _releaseSessionWindowFor(
          'embedded subtitle language fallback changed',
        );
      }
    }

    // 同一条内容在一次停留中只允许自动恢复一次；切到另一条后再返回，
    // 可以重新获得一次恢复机会。手动重试同一条不会重置该限制，避免真异常循环重开。
    if (item == null || item.id != _firstFrameAutoRetryItemId) {
      _firstFrameAutoRetryItemId = null;
    }

    // 防重复调用：相同 item 和相同语言源在 500ms 内忽略
    if (item != null && _lastPlayItemRequest != null) {
      final isSameItem =
          item.id == _lastPlayItemRequest!.id &&
          item.episode.videoSource == _lastPlayItemRequest!.episode.videoSource;
      final timeSinceLastCall = DateTime.now().difference(_lastPlayItemTime);
      if (!forceReopen &&
          isSameItem &&
          state.status != PlayerPlaybackStatus.error &&
          timeSinceLastCall.inMilliseconds < 500) {
        developer.log(
          'playItem: 忽略重复调用 - itemId=${item.id}, '
          'timeSinceLastCall=${timeSinceLastCall.inMilliseconds}ms',
        );
        return;
      }
    }
    _lastPlayItemRequest = item;
    _lastPlayItemTime = DateTime.now();

    ref.read(playerSessionRegistryProvider.notifier).register(sessionKey);
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
      if (startupPreload.status == PlayerStartupPreloadStatus.pending &&
          startupPreload.matchesSource(item)) {
        // startup 预热只保留 playlist、初始化首段和续播目标段，且与本地代理共用
        // 稳定 key 的 singleflight。真实播放加入后会优先消费同一资源；不再在刚
        // 拿到地址的 20~30ms 内整体取消，避免高续播位置来不及拉到目标分片。
        _logTiming(
          'startup critical segment relay retained for active playback',
          itemId: item.id,
          source: item.episode.videoSource,
        );
        ref
            .read(playerStartupPreloadControllerProvider.notifier)
            .promotePendingForActivePlayback(
              itemId: item.id,
              sourceUrl: item.episode.videoSource!,
            );
      } else if (startupPreload.status == PlayerStartupPreloadStatus.pending) {
        // 首帧路径只能服务当前前台视频。不同剧的 Home 预热不能和当前
        // manifest/首段抢带宽；它既无法被本次播放复用，也不应继续占用唯一
        // startup preload slot。
        _logTiming(
          'startup preload cancelled for foreground playback',
          itemId: item.id,
          source: item.episode.videoSource,
          details: _timingDetails([
            'startupItemId=${startupPreload.itemId ?? 'null'}',
            'startupSource=${startupPreload.sourceUrl ?? 'null'}',
          ]),
        );
        unawaited(
          ref
              .read(playerStartupPreloadControllerProvider.notifier)
              .cancel(
                reason: 'foreground playback target differs',
                syncState: false,
              ),
        );
      }
    }

    if (item == null) {
      // 空 item 表示 feed 当前没有可播放目标。需要暂停并清掉 source，但不把它记为
      // error，否则空列表/切分类会误触发播放失败 UI。
      _accessOverlayPausedItemId = null;
      _stopWatchProgressReportTimer();
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
        _usesCurrentMediaSource(item) &&
        state.status != PlayerPlaybackStatus.error;
    if (!forceReopen && isSameSource && !state.hasEnded) {
      _applyMetadataDurationFallback(item.episode.duration);
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
    if (!forceReopen) {
      _firstFrameVideoRecoveryAttempted = false;
    }
    _unexpectedPauseRecoveryDeadline = null;
    _unexpectedPauseRecoveryInFlight = false;
    _preparedTakeoverPlayPending = false;
    _preparedTakeoverPausedWhileOpening = false;
    _positionRollbackRecoveryInFlight = false;
    _userPauseRequested = false;
    _resetWatchProgressReportTimer();
    _firstFrameProgressProbeTimer?.cancel();
    _firstFrameVideoRecoveryTimer?.cancel();
    _cancelFirstFrameTimeout();
    _surfaceFirstFrameRenderWaitStartedAt = null;
    _surfaceFirstFrameRenderWaitItemId = null;
    _surfaceFirstFrameRenderWaitController = null;
    _pendingSubtitleLoadItem = null;
    _logTiming(
      'trace generation assigned',
      itemId: item.id,
      source: sourceHint,
      details: 'generation=$generation',
    );
    _pauseWhenOpenCompletes = false;
    _accessOverlayPausedItemId = null;
    final resumeProgress = _normalizeResumeProgress(
      await _resumeProgressForItem(item.id),
      item.episode.duration,
    );
    final resumeProgressWasPending = _lastResumeProgressWasPending;
    final resumeProgressRequiresSeekAfterOpen =
        _lastResumeProgressRequiresSeekAfterOpen;
    final resumeStart = resumeProgress?.canResume == true
        ? resumeProgress!.position
        : null;
    // Loading can begin just before the page is hidden. Do not let a delayed
    // request put the controller back into opening (or open media) after the
    // visibility gate has already been closed.
    if (!_isCurrent(generation) || !_isPlaybackVisible) {
      if (ref.mounted && !_isPlaybackVisible) {
        state = state.copyWith(
          status: PlayerPlaybackStatus.paused,
          isBuffering: false,
        );
      }
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.opening,
      hasFirstFrame: false,
      hasRenderedFirstFrame: false,
      isBuffering: true,
      position: Duration.zero,
      duration: resumeStart != null && resumeProgress != null
          ? _resumeDisplayDuration(
              resumeProgress.duration,
              item.episode.duration,
            )
          : _effectiveDuration(Duration.zero, item.episode.duration),
      bufferedPosition: Duration.zero,
      isSeeking: false,
      hasEnded: false,
      currentItemId: item.id,
      currentSource: sourceHint,
      clearError: true,
      clearSeekPreview: true,
      availableSubtitles: const [],
      availableEpisodeSources: item.episode.episodeSources,
      subtitleCues: const [],
      currentSubtitleText: '',
      clearSubtitle: true,
      clearSubtitleLanguage: item.episode.episodeSources.isEmpty,
      isSubtitleSelectionResolved: item.episode.episodeSources.isNotEmpty,
      currentSubtitleLanguage: item.episode.episodeSources.isEmpty
          ? null
          : _subtitleLanguageCodeForEpisodeSource(item.episode),
      availableVideoQualities: startupQualityPlan?.qualities ?? const [],
      isVideoQualityLoading: startupQualityPlan == null,
      selectedVideoQualityId:
          startupQualityPlan?.effectiveQualityId ?? _preferredVideoQualityId,
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );
    _yieldBackgroundPreloadsToOpeningPlayback(
      itemId: item.id,
      playbackGeneration: generation,
    );
    // Playlist inspection is concurrent with media opening.  It populates the
    // settings cache without delaying first frame or a later three-dot tap.
    // `item` can be a concrete manual rendition. Always inspect the master
    // playlist retained above so the settings sheet keeps every option.
    final qualityMaster = _currentQualityMasterItem;
    final qualityMasterSource = qualityMaster?.episode.videoSource;
    if (startupQualityPlan == null &&
        qualityMaster != null &&
        qualityMasterSource != null &&
        qualityMasterSource.isNotEmpty) {
      unawaited(_inspectVideoQualities(qualityMaster, qualityMasterSource));
    }
    _armFirstFrameTimeout(generation: generation, item: item);

    var didResolveSource = false;
    try {
      final windowItemsBeforeTake = _windowItemsText();
      // prepared/retained 命中时直接接管已经 open 的 session，避免同一个 item
      // 重复 open。命中窗口只覆盖相邻滑动，不承诺覆盖所有 HLS preload 候选。
      final isForYouEntryWarmup = _forYouEntryWarmItemId == item.id;
      final prepared = _prepareManager.takeIfMatches(item.id);
      if (isForYouEntryWarmup) {
        _forYouEntryWarmReleaseTimer?.cancel();
        _forYouEntryWarmItemId = null;
      }
      if (prepared != null &&
          prepared.kind != PreparedPlaybackSessionKind.retained &&
          resumeStart != null &&
          resumeProgressWasPending) {
        _logTiming(
          'prepared session skipped for resume start',
          itemId: item.id,
          source: prepared.source.playableSource,
          details: _timingDetails([
            'resumeMs=${resumeStart.inMilliseconds}',
            'kind=${prepared.kind.name}',
          ]),
        );
        await prepared.dispose();
      }
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
      if (prepared != null &&
          (prepared.kind == PreparedPlaybackSessionKind.retained ||
              !(resumeStart != null && resumeProgressWasPending))) {
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
          // 后台预热的解码首帧不等于当前 PageView 中的原生 Surface 已经上屏。
          // iOS 接管同一个 session 时 width stream 通常不会再次发射，因此必须主动
          // 等待新挂载的 Video widget 确认实际渲染，不能沿用预热阶段的首帧状态。
          hasRenderedFirstFrame: false,
          position: prepared.position,
          duration: _effectiveDuration(
            prepared.duration,
            item.episode.duration,
          ),
          bufferedPosition: prepared.bufferedPosition,
        );
        _currentPlaybackHasFirstFrame = prepared.hasFirstFrame;
        if (prepared.hasFirstFrame) {
          _cancelFirstFrameTimeout();
          _waitForVideoSurfaceFirstFrameRendered();
        }
        _currentPlaybackPosition = prepared.position;
        _currentPlaybackDuration = _effectiveDuration(
          prepared.duration,
          item.episode.duration,
        );
        _currentPlaybackBufferedPosition = prepared.bufferedPosition;
        await _restoreProgressIfNeeded(resumeProgress, generation);
        if (!ref.mounted || !_isCurrent(generation)) {
          return;
        }

        // 加载字幕
        _loadSubtitlesForItem(item);

        if (!_isPlaybackVisible || _pauseWhenOpenCompletes) {
          await _session.pause();
          state = state.copyWith(
            status: PlayerPlaybackStatus.paused,
            isBuffering: false,
          );
          return;
        }
        await _session.setVolume(100);
        // 接管后台已 warm-up 的 session 后，部分原生播放器可能在首个 play
        // command 后立即回报 playing=false。沿用 prepare 期间的一次性恢复窗口，
        // 避免画面已切换但播放没有真正开始。
        _unexpectedPauseRecoveryDeadline = DateTime.now().add(
          const Duration(seconds: 12),
        );
        _logTiming(
          'prepared takeover interruption guard armed',
          itemId: item.id,
          source: prepared.source.playableSource,
          details: 'guardMs=12000',
        );
        _logTiming('session play called', itemId: item.id, source: sourceHint);
        _preparedTakeoverPlayPending = true;
        var pausedWhileOpening = false;
        try {
          await _session.play();
          pausedWhileOpening = _preparedTakeoverPausedWhileOpening;
        } finally {
          _preparedTakeoverPlayPending = false;
          _preparedTakeoverPausedWhileOpening = false;
        }
        if (!ref.mounted || !_isCurrent(generation)) {
          return;
        }
        _setPlayingStateAndSyncProgressTimer(
          isBuffering: !prepared.hasFirstFrame,
        );
        if (pausedWhileOpening) {
          unawaited(_recoverFromUnexpectedPause());
        }
        // 页面在 prepared session 接管前可能已把“预热下一条”延迟到当前首帧。
        // 接管的 session 若本来已有首帧，width stream 不一定会再次发射，导致延迟
        // 任务永远不 flush，用户只看一两秒就继续下滑时第三条会变成冷开。
        if (prepared.hasFirstFrame) {
          _flushDeferredPreloadAfterFirstFrame(
            reason: 'prepared session takeover',
          );
        }
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
      var playbackSource = await ref
          .read(playerPlaybackSourceRepositoryProvider)
          .resolve(item, maxVideoHeight: _automaticVideoHeightCap());
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
        if (!_isPlaybackVisible) {
          state = state.copyWith(
            status: PlayerPlaybackStatus.paused,
            isBuffering: false,
          );
        }
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
        details: resumeStart == null
            ? 'reason=media open play=true'
            : 'reason=resume open start autoplay',
      );
      try {
        await _session.open(
          playbackSource.playableSource,
          play: _isPlaybackVisible && !_pauseWhenOpenCompletes,
          start: resumeStart,
          httpHeaders: playbackSource.httpHeaders,
        );
      } catch (error) {
        // The local proxy is an acceleration layer, never a prerequisite for
        // playback. A failure can happen only after it has produced the local
        // URL (for example when the proxy receives a CDN 403), so the source
        // resolver cannot catch it. Retry the original server URL once before
        // entering the normal media-failure path.
        if (_isLocalHlsProxySource(playbackSource.playableSource) &&
            playbackSource.remoteUrl != playbackSource.playableSource) {
          _logTiming(
            'media open retry with remote source',
            itemId: item.id,
            source: playbackSource.remoteUrl,
            details: 'reason=local_hls_proxy_open_failed error=$error',
          );
          await _session.open(
            playbackSource.remoteUrl,
            play: _isPlaybackVisible && !_pauseWhenOpenCompletes,
            start: resumeStart,
            httpHeaders: playbackSource.httpHeaders,
          );
          playbackSource = playbackSource.withPlayableSource(
            playbackSource.remoteUrl,
          );
          _currentPlaybackSource = playbackSource;
          state = state.copyWith(currentSource: playbackSource.playableSource);
        } else {
          // A route/Video surface teardown can dispose the native Player just
          // before a user retry reaches open. Do not reuse that session (or its
          // VideoController): replace it once and retry this exact open. Other
          // media errors retain the normal failure path below.
          if (!_isDisposedPlayerError(error) ||
              !await _replaceDisposedSessionForOpen(generation)) {
            rethrow;
          }
          _logTiming(
            'media open retry with replacement session',
            itemId: item.id,
            source: playbackSource.playableSource,
            details: 'reason=disposed_player',
          );
          await _session.open(
            playbackSource.playableSource,
            play: _isPlaybackVisible && !_pauseWhenOpenCompletes,
            start: resumeStart,
            httpHeaders: playbackSource.httpHeaders,
          );
        }
      }
      if (_preferredPlaybackRate != 1.0) {
        await _session.setRate(_preferredPlaybackRate);
      }
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
        if (!_isPlaybackVisible || _pauseWhenOpenCompletes) {
          await _session.pause();
          if (ref.mounted && !_isPlaybackVisible) {
            state = state.copyWith(
              status: PlayerPlaybackStatus.paused,
              isBuffering: false,
            );
          }
        }
        return;
      }

      // Media.start is only a hint for some HLS backends. For the explicit
      // For You completion handoff, issue one authoritative seek after the
      // source is open so the rendered video cannot remain at a server-chosen
      // middle position while the UI shows the requested rewind point.
      if (resumeStart != null && resumeProgressRequiresSeekAfterOpen) {
        await _seekWithWatchBoundary(resumeStart);
        if (!ref.mounted || !_isCurrent(generation)) {
          return;
        }
        _logTiming(
          'explicit handoff rewind seek applied',
          itemId: item.id,
          source: playbackSource.playableSource,
          details: 'positionMs=${resumeStart.inMilliseconds}',
        );
      }

      if (resumeStart != null && resumeProgress != null) {
        _lastAppliedResumeGeneration = generation;
        _lastAppliedResumeItemId = resumeProgress.itemId;
        _lastAppliedResumePosition = resumeStart;
        _resumeGuardRepairAttempts = 0;
        _armRestoreFloor(resumeStart, generation);
        state = state.copyWith(
          position: resumeStart,
          duration: resumeProgress.duration > Duration.zero
              ? _resumeDisplayDuration(
                  resumeProgress.duration,
                  item.episode.duration,
                )
              : state.duration,
          bufferedPosition: state.bufferedPosition < resumeStart
              ? resumeStart
              : state.bufferedPosition,
        );
        _currentPlaybackPosition = resumeStart;
        if (resumeProgress.duration > Duration.zero) {
          _currentPlaybackDuration = _resumeDisplayDuration(
            resumeProgress.duration,
            item.episode.duration,
          );
        }
        if (_currentPlaybackBufferedPosition < resumeStart) {
          _currentPlaybackBufferedPosition = resumeStart;
        }
        _updateCurrentSubtitle(resumeStart);
      } else {
        await _restoreProgressIfNeeded(resumeProgress, generation);
      }

      // 不阻塞 media open，但 loading 必须等真实首帧/尺寸事件后再消失。

      // 页面已经切走时，source resolve/open 仍可能刚好完成。此时绝不能再
      // 调用 play，否则 For You 会在隐藏 tab 中漏出音频。
      if (!_isPlaybackVisible || _pauseWhenOpenCompletes) {
        await _session.pause();
        if (ref.mounted && _isCurrent(generation)) {
          state = state.copyWith(
            status: PlayerPlaybackStatus.paused,
            isBuffering: !_currentPlaybackHasFirstFrame,
            hasFirstFrame: _currentPlaybackHasFirstFrame,
          );
        }
        return;
      }

      // 确保开始播放
      await _session.play();
      if (!ref.mounted || !_isCurrent(generation)) {
        return;
      }

      // 字幕文件下载不参与首帧路径，避免失败重试和首段加载抢资源。
      _loadSubtitlesForItem(item);

      if (!_isPlaybackVisible || _pauseWhenOpenCompletes) {
        await _session.pause();
        state = state.copyWith(
          status: PlayerPlaybackStatus.paused,
          isBuffering: !_currentPlaybackHasFirstFrame,
          hasFirstFrame: _currentPlaybackHasFirstFrame,
        );
        return;
      }
      _setPlayingStateAndSyncProgressTimer(
        isBuffering: !_currentPlaybackHasFirstFrame,
        hasFirstFrame: _currentPlaybackHasFirstFrame,
      );
    } catch (error, st) {
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
      developer.log(
        'playItem: 播放失败 - itemId=${item.id}, source=$sourceHint, error=$error\n$st',
      );
      if (!_isCurrent(generation)) {
        return;
      }
      _markPlaybackFailed(
        error: error,
        errorKind: errorKind,
        expectedGeneration: generation,
      );
      if (rethrowOnFailure) {
        Error.throwWithStackTrace(error, st);
      }
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

    final currentItem = items[currentIndex];
    if (_shouldDeferPreloadUntilFirstFrame &&
        (state.currentItemId != currentItem.id ||
            state.currentSource == null ||
            (state.status == PlayerPlaybackStatus.opening &&
                !state.hasFirstFrame))) {
      _deferredPreloadItems = List<PlayerFeedItem>.unmodifiable(items);
      _deferredPreloadIndex = currentIndex;
      _logTiming(
        'preload deferred until first frame',
        itemId: currentItem.id,
        source: state.currentSource,
        details: _timingDetails([
          'currentIndex=$currentIndex',
          'itemCount=${items.length}',
          'status=${state.status.name}',
          'playbackItemId=${state.currentItemId ?? 'none'}',
          'hasSource=${state.currentSource != null}',
        ]),
      );
      return;
    }

    final skipped = <String>[];
    final config = ref.read(playerPreloadConfigProvider);
    final isForYou = items[currentIndex].mode == PlayerFeedMode.forYou;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final forwardPreloadCount = config.forwardHlsPreloadCountFor(isForYou);
    // For You 和 iOS 的网络优先级固定为 current > next。iOS 单码率 HLS 的
    // 反向首段下载会在当前集播放期间与当前分片抢带宽；回滑由已落盘分片承担。
    // 即使未来远程配置误下发了 backward count，也不能抢当前集或下一集的首帧带宽。
    final backwardPreloadCount = isForYou || isIos
        ? 0
        : config.backwardHlsPreloadCountFor(false);
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
    final sessionForwardCandidates = _preloadCandidatesInDirection(
      items,
      currentIndex,
      direction: 1,
      count: config.effectivePreparedForwardSessionCount,
      skipped: <String>[],
    ).where((item) => !_usesCurrentMediaSource(item)).toList(growable: false);
    final sessionBackwardCandidates = _preloadCandidatesInDirection(
      items,
      currentIndex,
      direction: -1,
      count: config.effectiveRetainedBackwardSessionCount,
      skipped: <String>[],
    ).where((item) => !_usesCurrentMediaSource(item)).toList(growable: false);

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
    final sessionAllowedIds = <String>{
      if (state.currentItemId != null) state.currentItemId!,
      ...sessionForwardCandidates.map((item) => item.id),
      ...sessionBackwardCandidates.map((item) => item.id),
    };
    final previousActivePreloadAllowedIds = _activePreloadAllowedIds.toSet();
    _logTiming(
      'preload candidates',
      itemId: state.currentItemId,
      details: _timingDetails([
        'currentIndex=$currentIndex',
        'candidates=${candidates.map((candidate) => candidate.id).join(',')}',
        'skipped=${skipped.join(',')}',
        'allowedIds=${allowedIds.join(',')}',
        'sessionAllowedIds=${sessionAllowedIds.join(',')}',
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
      sessionAllowedIds,
      reason: 'stale generation/window trim',
    );

    _syncPreloadState();

    if (state.currentItemId != null &&
        state.currentSource != null &&
        config.effectivePreparedForwardSessionCount > 0) {
      final nextItem = sessionForwardCandidates.isEmpty
          ? null
          : sessionForwardCandidates.first;
      if (nextItem != null) {
        // 只 prepare 第一个 forward playable item，保持 previous/current/next 窗口。
        // 不要按 HLS preload 数量循环 prepare，否则会变成播放器实例池。
        unawaited(_prepareNextItem(nextItem, preloadGeneration));
      }
    }

    for (final candidate in selectedCandidates) {
      // Resolve the user's rendition preference before any playlist/segment
      // request.  `candidate.id` remains stable, while its source becomes the
      // selected variant m3u8 when manual quality is active.
      final item = await _itemUsingPreferredVideoQuality(candidate);
      if (!ref.mounted ||
          _isSessionDisposed ||
          preloadGeneration != _preloadGeneration) {
        return;
      }
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
            .preload(item, maxVideoHeight: _automaticVideoHeightCap());
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

  /// PageView 手势预测仅预热 HLS HTTP 资源，不创建或 prepare media session。
  ///
  /// 真实播放器在页面 settled 后仍按 current/next/previous 三窗口策略接管；这里
  /// 只让即将进入的页面更早命中 playlist/segment 缓存或 singleflight。
  Future<void> preloadItemForPredictedViewport(PlayerFeedItem item) async {
    if (_isSessionDisposed || item.mode != PlayerFeedMode.forYou) {
      return;
    }
    final subtitlePreferredItem = _itemUsingPreferredEmbeddedSource(
      item,
      updatePreference: false,
    );
    final preferredItem = await _itemUsingPreferredVideoQuality(
      subtitlePreferredItem,
    );
    final sourceUrl = preferredItem.episode.videoSource;
    if (preferredItem.episode.isLocked ||
        preferredItem.episode.isUnavailable ||
        sourceUrl == null ||
        preferredItem.id == state.currentItemId ||
        _preloadedItemIds.contains(preferredItem.id) ||
        _predictivePreloadedItemIds.contains(preferredItem.id) ||
        _prepareManager.windowItemIds.contains(preferredItem.id) ||
        _predictivePreloadItemId == preferredItem.id) {
      return;
    }

    await cancelPredictedViewportPreload(reason: 'target_replaced');
    final generation = ++_predictivePreloadGeneration;
    _predictivePreloadItemId = preferredItem.id;
    _logTiming(
      'for you predictive hls start',
      itemId: preferredItem.id,
      source: sourceUrl,
      details: 'trigger=page_out_60 sessionCreated=false',
    );
    try {
      final startedAt = DateTime.now();
      final result = await ref
          .read(forYouPredictivePlaybackSourceRepositoryProvider)
          .preload(preferredItem, maxVideoHeight: _automaticVideoHeightCap());
      if (!ref.mounted ||
          _isSessionDisposed ||
          generation != _predictivePreloadGeneration) {
        return;
      }
      _predictivePreloadItemId = null;
      _setPreloadState(result);
      if (result.status == PlaybackPreloadStatus.success) {
        _predictivePreloadedItemIds.add(preferredItem.id);
        _preloadedItemIds.add(preferredItem.id);
      }
      _logTiming(
        'for you predictive hls end',
        itemId: preferredItem.id,
        source: sourceUrl,
        elapsed: DateTime.now().difference(startedAt),
        details: 'status=${result.status.name} sessionCreated=false',
      );
    } catch (error) {
      if (!ref.mounted ||
          _isSessionDisposed ||
          generation != _predictivePreloadGeneration) {
        return;
      }
      _predictivePreloadItemId = null;
      _setPreloadState(
        PlaybackPreloadState(
          itemId: preferredItem.id,
          sourceUrl: sourceUrl,
          status: PlaybackPreloadStatus.failed,
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
          error: error,
        ),
      );
      _logTiming(
        'for you predictive hls failed',
        itemId: preferredItem.id,
        source: sourceUrl,
        error: error,
      );
    }
  }

  /// 只停止预测尚未展开的后续请求；已经得到的分片仍由共享缓存保留。
  Future<void> cancelPredictedViewportPreload({required String reason}) async {
    final pendingItemId = _predictivePreloadItemId;
    if (pendingItemId == null) {
      return;
    }
    _predictivePreloadGeneration += 1;
    _predictivePreloadItemId = null;
    await _predictivePreloadManager.releasePending();
    _logTiming(
      'for you predictive hls cancelled',
      itemId: pendingItemId,
      details: 'reason=$reason',
    );
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
    _pauseWatchProgressReportTimer();
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
      final item = _itemUsingPreferredEmbeddedSource(
        items[index],
        updatePreference: false,
      );
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

  Future<void> togglePlay({bool pauseRequested = false}) async {
    if (_isSessionDisposed) {
      return;
    }

    if (state.status == PlayerPlaybackStatus.playing) {
      _accessOverlayPausedItemId = null;
      _pauseWatchProgressReportTimer();
      _userPauseRequested = true;
      state = state.copyWith(status: PlayerPlaybackStatus.paused);
      await _session.pause();
      _reportPauseWatchProgressIfNeeded();
      return;
    }

    if (pauseRequested &&
        state.status == PlayerPlaybackStatus.paused &&
        state.currentSource != null) {
      _reportPauseWatchProgressIfNeeded();
      return;
    }

    if (state.status != PlayerPlaybackStatus.paused ||
        state.currentSource == null) {
      return;
    }

    _pauseWhenOpenCompletes = false;
    _userPauseRequested = false;
    if (state.hasEnded) {
      await _seekWithWatchBoundary(Duration.zero);
      _ignoreNextCompleted = false;
      _currentPlaybackPosition = Duration.zero;
      state = state.copyWith(position: Duration.zero, hasEnded: false);
    }
    await _session.play();
    state = state.copyWith(
      status: PlayerPlaybackStatus.playing,
      hasEnded: false,
    );
    _syncWatchProgressReportTimer();
  }

  Future<void> replay() async {
    if (_isSessionDisposed || state.currentSource == null) {
      return;
    }
    _pauseWhenOpenCompletes = false;
    await _seekWithWatchBoundary(Duration.zero);
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
    _syncWatchProgressReportTimer();
  }

  Future<void> rewindFromEndAndPlay(Duration offset) async {
    if (_isSessionDisposed || state.currentSource == null) {
      return;
    }
    final duration = state.duration > Duration.zero
        ? state.duration
        : _currentPlaybackDuration;
    final target = duration > offset ? duration - offset : Duration.zero;
    _pauseWhenOpenCompletes = false;
    await _seekWithWatchBoundary(target);
    _ignoreNextCompleted = false;
    _currentPlaybackPosition = target;
    await _session.play();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.playing,
      position: target,
      hasEnded: false,
      clearSeekPreview: true,
    );
    _syncWatchProgressReportTimer();
  }

  Future<void> setPlaybackRate(double rate) async {
    if (_isSessionDisposed || !_supportedRates.contains(rate)) {
      return;
    }
    await _ratePreferenceReady;
    if (!ref.mounted || _isSessionDisposed) return;
    if (_isForYouSession) {
      // There is no For You speed control, but keep this boundary defensive
      // for callers added in the future.
      _preferredPlaybackRate = 1.0;
      state = state.copyWith(playbackRate: 1.0);
      return;
    }
    await _session.setRate(rate);
    _preferredPlaybackRate = rate;
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(playbackRate: rate);
    try {
      await (await SharedPreferences.getInstance()).setDouble(
        _ratePreferenceKey,
        rate,
      );
    } catch (_) {
      // Keep the successful playback change when persistence is unavailable.
    }
  }

  Future<void> pause() async {
    if (_isSessionDisposed) {
      return;
    }
    _accessOverlayPausedItemId = null;
    _pauseWatchProgressReportTimer();
    _userPauseRequested = true;
    state = state.copyWith(status: PlayerPlaybackStatus.paused);
    await _session.pause();
    _reportPauseWatchProgressIfNeeded();
  }

  /// 上报观看进度。
  Future<void> reportWatchProgress({
    required int eventType,
    bool autoUnlockNext = false,
    PlayerFeedItem? item,
  }) async {
    unawaited(
      _reportWatchProgress(
        eventType: eventType,
        autoUnlockNext: autoUnlockNext,
        item: item,
      ),
    );
  }

  Future<void> persistCurrentProgress() {
    return _persistProgressIfNeeded();
  }

  Future<void> _reportWatchProgress({
    required int eventType,
    bool autoUnlockNext = false,
    PlayerFeedItem? item,
  }) async {
    if (_isSessionDisposed ||
        state.currentItemId == null ||
        _currentPlaybackSource == null) {
      return;
    }

    try {
      final feedState = ref.read(playerFeedControllerProvider(sessionKey));
      final currentItem = item ?? feedState.currentItem;
      if (currentItem == null) {
        return;
      }

      final dramaId = int.tryParse(currentItem.content.id) ?? 0;
      final episodeId = int.tryParse(currentItem.episode.id);
      final episodeNo = currentItem.episode.number;
      final watchSecond = state.position.inSeconds;
      final durationSecond = _reportableDurationSecond(
        currentItem,
        watchSecond: watchSecond,
      );
      if (_shouldSkipDuplicateStartReport(
        eventType: eventType,
        itemId: currentItem.id,
      )) {
        _logTiming(
          'report watch progress skipped duplicate start',
          itemId: state.currentItemId,
          details: _timingDetails([
            'eventType=$eventType',
            'generation=$_generation',
            'reportedItemId=${currentItem.id}',
          ]),
        );
        return;
      }
      _markWatchProgressEventReported(
        eventType: eventType,
        itemId: currentItem.id,
      );
      _logTiming(
        'report watch progress',
        itemId: state.currentItemId,
        details: _timingDetails([
          'eventType=$eventType',
          'dramaId=$dramaId',
          'episodeId=$episodeId',
          'episodeNo=$episodeNo',
          'durationSecond=$durationSecond',
          'watchSecond=$watchSecond',
          'autoUnlockNext=$autoUnlockNext',
        ]),
      );

      await ref
          .read(playerRemoteDataSourceProvider)
          .reportWatchProgress(
            autoUnlockNext: autoUnlockNext,
            dramaId: dramaId,
            durationSecond: durationSecond,
            episodeId: episodeId,
            episodeNo: episodeNo,
            eventType: eventType,
            watchSecond: watchSecond,
          );
    } catch (error) {
      _logTiming(
        'report watch progress error',
        itemId: state.currentItemId,
        error: error,
      );
    }
  }

  bool _shouldSkipDuplicateStartReport({
    required int eventType,
    required String itemId,
  }) {
    return eventType == 1 &&
        _lastStartReportGeneration == _generation &&
        _lastStartReportItemId == itemId &&
        _lastStartReportSource == state.currentSource;
  }

  void _markWatchProgressEventReported({
    required int eventType,
    required String itemId,
  }) {
    if (eventType != 1) {
      return;
    }
    _lastStartReportGeneration = _generation;
    _lastStartReportItemId = itemId;
    _lastStartReportSource = state.currentSource;
  }

  void _reportPauseWatchProgressIfNeeded() {
    final itemId = state.currentItemId;
    if (itemId == null) {
      return;
    }
    final watchSecond = state.position.inSeconds;
    if (_lastPauseReportItemId == itemId &&
        _lastPauseReportWatchSecond == watchSecond) {
      return;
    }
    _lastPauseReportItemId = itemId;
    _lastPauseReportWatchSecond = watchSecond;
    unawaited(_reportWatchProgress(eventType: 3)); // 3: pause
  }

  int _reportableDurationSecond(
    PlayerFeedItem item, {
    required int watchSecond,
  }) {
    final candidates = [
      state.duration,
      _currentPlaybackDuration,
      item.episode.duration,
    ];
    for (final duration in candidates) {
      if (duration != null && duration > Duration.zero) {
        return duration.inSeconds;
      }
    }
    return watchSecond > 0 ? watchSecond : 0;
  }

  void beginSeek() {
    if (!state.isSeekAllowed || _isSessionDisposed) {
      return;
    }
    _pauseWatchProgressReportTimer();
    _restoreFloorTimer?.cancel();
    _restoreFloorPosition = null;
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
    await _seekWithWatchBoundary(target);
    if (_wasPlayingBeforeSeek) {
      await _session.play();
      if (ref.mounted) {
        state = state.copyWith(
          status: PlayerPlaybackStatus.playing,
          hasEnded: false,
          clearSeekPreview: true,
        );
        _syncWatchProgressReportTimer();
      }
    } else if (ref.mounted) {
      state = state.copyWith(
        status: PlayerPlaybackStatus.paused,
        hasEnded: false,
        clearSeekPreview: true,
      );
      _syncWatchProgressReportTimer();
    }
  }

  void cancelSeek() {
    if (!state.isSeeking) {
      return;
    }
    state = state.copyWith(isSeeking: false, clearSeekPreview: true);
    _syncWatchProgressReportTimer();
  }

  Future<void> pauseForVisibility({bool syncState = true}) {
    return detachSurfaceForVisibility(syncState: syncState);
  }

  /// Synchronously close the playback gate before asynchronous visibility
  /// cleanup starts. A source resolve/open that finishes after this point must
  /// remain paused even if its earlier request cleared the pause flag.
  void markHiddenForVisibility() {
    if (_isSessionDisposed) {
      return;
    }
    ++_visibilityDetachEpoch;
    _isPlaybackVisible = false;
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    ++_generation;
  }

  /// 页面播放器之间交接时的轻量暂停。
  ///
  /// 与 [pauseForVisibility] 不同，这里不等待 prepared window、HLS preload 和本地
  /// 进度写入完成，也不释放当前 media session。For You 仍存活在路由下方时，可以在
  /// 返回后复用同一个 source，只做 seek + play。
  Future<void> pauseForRouteHandoff() async {
    if (_isSessionDisposed) {
      return;
    }
    ++_visibilityDetachEpoch;
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    _pauseWatchProgressReportTimer();
    unawaited(_persistProgressIfNeeded());
    ++_generation;
    await _session.pause();
    if (!ref.mounted) {
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

    // 这些资源不参与当前 source 的快速恢复，可以后台释放，不能阻塞路由跳转。
    unawaited(_releaseSessionWindowFor('route handoff'));
    unawaited(_disposePreloads());
  }

  /// Keeps only For You's paused current session for an immediate return from
  /// the ordinary player. Its prepared/retained neighbours are released, so
  /// this reservation is always lower priority than the foreground player.
  Future<void> retainForCompetingPlayer() async {
    if (!_isForYouSession || _isSessionDisposed) {
      return;
    }
    _isRetainedForCompetingPlayer = true;
    await pauseForRouteHandoff();
  }

  bool get isRetainedForCompetingPlayer => _isRetainedForCompetingPlayer;

  Future<void> _releaseRetainedForYouSession(String reason) async {
    if (_isForYouSession) return;
    if (!ref
        .read(playerSessionRegistryProvider)
        .contains(PlayerPlaybackSessionKeys.forYouTab)) {
      return;
    }
    final forYou = ref.read(
      playerPlaybackControllerProvider(
        PlayerPlaybackSessionKeys.forYouTab,
      ).notifier,
    );
    if (!forYou.isRetainedForCompetingPlayer) return;
    _logTiming('release retained For You session', details: 'reason=$reason');
    await forYou.suspendForCompetingPlayer();
  }

  /// 返回上一个播放器页面前只暂停并卸载当前 Surface。
  ///
  /// route pop 后 provider dispose 会完成强释放；这里不把释放耗时放在返回手势的关键
  /// 路径上。
  Future<void> detachSurfaceForRoutePop() async {
    if (_isSessionDisposed) {
      return;
    }
    ++_visibilityDetachEpoch;
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    unawaited(_persistProgressIfNeeded());
    ++_generation;
    await _session.pause();
    if (!ref.mounted) {
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

  Future<void> resumeAfterVisibilityPause() async {
    if (_isSessionDisposed) {
      return;
    }
    // 普通播放器正在前台时，通知带来的 inactive/resumed 会同时回调被
    // IndexedStack 保留的 For You。此时绝不能因生命周期恢复而重新 play。
    if (sessionKey == PlayerPlaybackSessionKeys.forYouTab &&
        _isSuspendedForCompetingPlayer) {
      _logTiming(
        'for you visibility resume ignored while competing player is active',
      );
      return;
    }
    _isPlaybackVisible = true;
    if (sessionKey == PlayerPlaybackSessionKeys.forYouTab) {
      ref.read(hlsTrafficGateProvider).resumeForYou();
    }
    final suspendedItem = _visibilitySuspendedItem;
    if (suspendedItem != null && state.currentSource == null) {
      _visibilitySuspendedItem = null;
      _pauseWhenOpenCompletes = false;
      _lastPlayItemRequest = null;
      await playItem(suspendedItem);
      return;
    }
    if (state.status != PlayerPlaybackStatus.paused ||
        state.currentSource == null) {
      return;
    }

    // Android 在外部分享页返回时可能已销毁 VideoOutput 的 Surface。若外跳前
    // 仍在首帧 loading，旧 session 即使重新 play 也不会再向新 Surface 输出画面，
    // 最终会出现“音频继续、页面黑屏且 loading 不消失”。此时只在自动续播路径
    // 重开当前 item，让 media_kit 为新 Surface 建立新的 video output；已经成功
    // 上屏过的播放仍复用 session，避免普通前后台切换产生不必要的重新请求。
    final item = _currentOriginalItem;
    if (!state.hasRenderedFirstFrame &&
        item != null &&
        item.id == state.currentItemId) {
      _visibilityDetachEpoch += 1;
      _pauseWhenOpenCompletes = false;
      _accessOverlayPausedItemId = null;
      _lastPlayItemRequest = null;
      _logTiming(
        'visibility resume reopen before first frame',
        itemId: item.id,
        source: state.currentSource,
        details: _timingDetails([
          'hasFirstFrame=${state.hasFirstFrame}',
          'hasRenderedFirstFrame=${state.hasRenderedFirstFrame}',
        ]),
      );
      await playItem(item, forceReopen: true);
      return;
    }

    _visibilityDetachEpoch += 1;
    _pauseWhenOpenCompletes = false;
    _accessOverlayPausedItemId = null;
    await _session.play();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.playing,
      isBuffering: !state.hasFirstFrame,
      hasEnded: false,
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );
    _syncWatchProgressReportTimer();
  }

  /// 重新挂载因不可见而卸载的 video surface，但保持用户的暂停状态。
  Future<void> restoreSurfaceAfterVisibilityPause() async {
    if (_isSessionDisposed ||
        state.status != PlayerPlaybackStatus.paused ||
        state.currentSource == null) {
      return;
    }
    _visibilityDetachEpoch += 1;
    // 路由返回后即使维持用户原有的暂停状态，页面也已经重新可见。若不恢复
    // 此开关，随后因广告解锁触发的 playItem 会被当作后台播放而直接忽略。
    _isPlaybackVisible = true;
    _pauseWhenOpenCompletes = false;
    state = state.copyWith(
      isBuffering: false,
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );
  }

  /// 被普通播放器暂时抢占时释放 For You 的 native decoder。
  ///
  /// Android 上暂停的 MediaCodec 仍会占用解码资源；普通页同时会打开 current
  /// 与相邻预热 session。保留 For You 的 session 会让返回后继续下滑时无法创建
  /// 新 decoder。返回 For You 时重新创建 session 并打开当前 item。
  Future<void> _enqueueCompetingPlayerTransition(
    Future<void> Function() operation,
  ) {
    final next = _competingPlayerTransition.then<void>(
      (_) => operation(),
      onError: (_, _) => operation(),
    );
    // Keep the queue usable after a native player failure. The caller still
    // receives [next] and can handle that failure independently.
    _competingPlayerTransition = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  Future<void> suspendForCompetingPlayer() =>
      _enqueueCompetingPlayerTransition(_suspendForCompetingPlayer);

  Future<void> _suspendForCompetingPlayer() async {
    if (!ref.mounted || _isSessionDisposed) return;
    _isSuspendedForCompetingPlayer = true;
    _isRetainedForCompetingPlayer = false;
    ref.read(hlsTrafficGateProvider).suspendForYou();
    _pauseWhenOpenCompletes = true;
    _pauseWatchProgressReportTimer();
    ++_generation;
    final suspendedItem = _currentOriginalItem;
    if (suspendedItem != null) {
      _visibilitySuspendedItem = suspendedItem;
    }
    await _session.pause();
    // The whole prepared window is released below. Pausing it first is
    // redundant and can race with an in-flight prepared-session takeover.
    await _releaseSessionWindowFor('competing player');
    await _disposePreloads();
    await _cancelSessionStreams();
    await _disposeSessionOnly(shouldPause: false);
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
    if (!ref.mounted) return;
    state = state.copyWith(
      status: PlayerPlaybackStatus.paused,
      isBuffering: false,
      currentItemId: null,
      clearSource: true,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.detached,
      clearVideoController: true,
    );
    _logTiming(
      'for you suspended for competing player',
      details: _timingDetails(['sessionReleased=true', 'networkGate=closed']),
    );
  }

  /// 普通播放器已返回或用户明确切回 For You，才解除其抢占状态。
  Future<void> resumeAfterCompetingPlayer({
    bool restoreSuspendedPlayback = true,
  }) => _enqueueCompetingPlayerTransition(
    () => _resumeAfterCompetingPlayer(
      restoreSuspendedPlayback: restoreSuspendedPlayback,
    ),
  );

  Future<void> _resumeAfterCompetingPlayer({
    required bool restoreSuspendedPlayback,
  }) async {
    if (!ref.mounted) {
      return;
    }
    if (_isSessionDisposed) {
      _isSessionDisposed = false;
      _session = ref.read(playerPlaybackSessionFactoryProvider).call();
      _attachSessionStreams(_session);
      _logTiming(
        'create current session',
        details: 'reason=resume after competing player',
      );
    }
    _isSuspendedForCompetingPlayer = false;
    _isRetainedForCompetingPlayer = false;
    if (!restoreSuspendedPlayback) {
      // For You -> standard player -> For You may return on a different
      // episode. Replaying _visibilitySuspendedItem here would open the old
      // HLS source just before synchronizeExternalProgress opens the returned
      // episode, which races iOS's native decoder. The caller will issue the
      // single authoritative open/seek/play immediately afterwards.
      _isPlaybackVisible = true;
      _visibilitySuspendedItem = null;
      _pauseWhenOpenCompletes = false;
      if (sessionKey == PlayerPlaybackSessionKeys.forYouTab) {
        ref.read(hlsTrafficGateProvider).resumeForYou();
      }
      return;
    }
    await resumeAfterVisibilityPause();
  }

  /// Rebuilds a For You native session only after it has entered a terminal
  /// playback failure.  A route/tab return must not merely call `play()` on a
  /// controller whose Android VideoOutput or decoder has already died.
  ///
  /// This is deliberately narrower than a generic resume: normal opening and
  /// buffering keep their existing behaviour, while an error or a missing
  /// source for the visible item gets a fresh session.  Calls are serialised so
  /// Tab changes, pull-to-refresh and route returns cannot dispose a session
  /// that another recovery has just created.
  Future<void> recoverForYouPlaybackIfFailed(
    PlayerFeedItem? item, {
    required String trigger,
    bool forceRebuild = false,
  }) {
    if (sessionKey != PlayerPlaybackSessionKeys.forYouTab ||
        item == null ||
        item.episode.isLocked ||
        item.episode.isUnavailable ||
        item.episode.videoSource == null) {
      return Future<void>.value();
    }
    final shouldRecover =
        forceRebuild ||
        state.status == PlayerPlaybackStatus.error ||
        (state.currentItemId == item.id && state.currentSource == null);
    if (!shouldRecover) {
      return Future<void>.value();
    }
    final next = _forYouRecoveryOperation.then<void>(
      (_) => _recreateForYouSessionAndPlay(item, trigger: trigger),
      onError: (_, _) => _recreateForYouSessionAndPlay(item, trigger: trigger),
    );
    // Preserve a usable queue after a native failure. The caller still sees
    // the actual failure through [next].
    _forYouRecoveryOperation = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  Future<void> _recreateForYouSessionAndPlay(
    PlayerFeedItem item, {
    required String trigger,
  }) async {
    if (!ref.mounted ||
        sessionKey != PlayerPlaybackSessionKeys.forYouTab ||
        !_isPlaybackVisible ||
        _isSuspendedForCompetingPlayer) {
      return;
    }
    // A queued recovery may have become stale while the user refreshed or
    // swiped. Only rebuild the item that is still current.
    if (state.currentItemId != null && state.currentItemId != item.id) {
      return;
    }
    _logTiming(
      'for you rebuild failed session',
      itemId: item.id,
      source: item.episode.videoSource,
      details: _timingDetails(['trigger=$trigger']),
    );
    ++_generation;
    _cancelFirstFrameTimeout();
    _firstFrameProgressProbeTimer?.cancel();
    _firstFrameVideoRecoveryTimer?.cancel();
    _pauseWatchProgressReportTimer();
    await _releaseSessionWindowFor('for you failed session rebuild');
    await _disposePreloads();
    if (!_isSessionDisposed) {
      await _session.pause();
      await _cancelSessionStreams();
      await _disposeSessionOnly(shouldPause: false);
    }
    if (!ref.mounted || !_isPlaybackVisible || _isSuspendedForCompetingPlayer) {
      return;
    }
    _isSessionDisposed = false;
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _attachSessionStreams(_session);
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
    _lastPlayItemRequest = null;
    state = state.copyWith(
      status: PlayerPlaybackStatus.idle,
      clearSource: true,
      clearError: true,
      hasFirstFrame: false,
      hasRenderedFirstFrame: false,
      isBuffering: false,
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );
    await playItem(item, forceReopen: true);
  }

  Future<void> detachSurfaceForVisibility({bool syncState = true}) async {
    if (_isSessionDisposed) {
      return;
    }
    markHiddenForVisibility();
    final visibilityEpoch = _visibilityDetachEpoch;
    // 页面隐藏、切 tab、进后台都走这里。generation 先失效旧 open，避免异步 open
    // 完成后又自动 play；随后释放 session window 和 HTTP preload，防止隐藏页面继续
    // 占用音频/网络资源。
    _pauseWatchProgressReportTimer();
    await _persistProgressIfNeeded();
    if (visibilityEpoch != _visibilityDetachEpoch) {
      return;
    }
    ++_generation;
    await _session.pause();
    if (visibilityEpoch != _visibilityDetachEpoch) {
      return;
    }
    await _releaseSessionWindowFor('hidden');
    if (visibilityEpoch != _visibilityDetachEpoch) {
      return;
    }
    await _disposePreloads(syncState: syncState);
    if (visibilityEpoch != _visibilityDetachEpoch) {
      return;
    }
    if (!syncState || !ref.mounted) {
      return;
    }
    state = state.copyWith(
      status:
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
    _stopWatchProgressReportTimer();
    await _persistProgressIfNeeded();
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

  void detachVideoSurfaceForTeardown({bool syncState = true}) {
    if (!ref.mounted || state.videoController == null) {
      return;
    }
    _accessOverlayPausedItemId = null;
    _stopWatchProgressReportTimer();
    if (!syncState) {
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

  Future<void> disposeSession({
    bool syncState = true,
    Duration disposeDelay = Duration.zero,
  }) async {
    if (_isSessionDisposed) {
      return;
    }
    // 单剧页离开时做强释放：当前 session、prepared window、HLS pending 都要清掉。
    // For You tab 不走 disposeSession，而是 pauseForVisibility，以保留 tab provider。
    _pauseWhenOpenCompletes = true;
    _accessOverlayPausedItemId = null;
    _stopWatchProgressReportTimer();
    ++_generation;
    // The caller often cannot await page disposal. Issue the native pause
    // before cleanup work so no audio survives a route exit.
    final pauseFuture = _session.pause();
    await _persistProgressIfNeeded();
    await pauseFuture;
    await _releaseSessionWindowFor('dispose');
    await _disposePreloads(syncState: syncState);
    _preloadStates.clear();
    _preloadedItemIds.clear();
    await _disposeSessionOnly(disposeDelay: disposeDelay, shouldPause: false);
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

  /// Rebuild the native session after account/session cleanup while retaining
  /// this provider instance. For You is kept alive by StatefulShell, so simply
  /// disposing its native player leaves the long-lived controller permanently
  /// unable to accept later [playItem] calls.
  Future<void> resetForSessionCleanup() async {
    await disposeSession(syncState: false);
    await _cancelSessionStreams();
    _isSessionDisposed = false;
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _attachSessionStreams(_session);
    _currentOriginalItem = null;
    _visibilitySuspendedItem = null;
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
    _lastPlayItemRequest = null;
    _pauseWhenOpenCompletes = false;
    _isSuspendedForCompetingPlayer = false;
    if (ref.mounted) {
      state = PlayerPlaybackState.initial(
        videoController: _session.videoController,
      ).copyWith(playbackRate: _preferredPlaybackRate);
    }
    _logTiming('create current session', details: 'reason=session cleanup');
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
    final effectiveBuffering = isBuffering || !state.hasFirstFrame;
    _logTiming(
      isBuffering ? 'buffering start' : 'buffering end',
      details: !isBuffering && !state.hasFirstFrame
          ? 'keptLoadingUntilFirstFrame=true'
          : null,
    );
    state = state.copyWith(isBuffering: effectiveBuffering);
    _updateDecoderPressureStability();
    _syncWatchProgressReportTimer();
  }

  void _handlePlaying(bool isPlaying) {
    if (!ref.mounted) {
      return;
    }
    final pauseRecoveryDeadline = _unexpectedPauseRecoveryDeadline;
    final now = DateTime.now();
    final pauseRecoveryRemainingMs = pauseRecoveryDeadline
        ?.difference(now)
        .inMilliseconds;
    final pauseRecoveryEligible = !isPlaying && _shouldRecoverUnexpectedPause();
    if (!isPlaying) {
      _logTiming(
        'native playing false observed',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails([
          'status=${state.status.name}',
          'positionMs=${state.position.inMilliseconds}',
          'hasFirstFrame=${state.hasFirstFrame}',
          'hasEnded=${state.hasEnded}',
          'isBuffering=${state.isBuffering}',
          'visible=$_isPlaybackVisible',
          'pauseWhenOpenCompletes=$_pauseWhenOpenCompletes',
          'userPauseRequested=$_userPauseRequested',
          'recoveryInFlight=$_unexpectedPauseRecoveryInFlight',
          'recoveryRemainingMs=${pauseRecoveryRemainingMs ?? 'none'}',
          'recoveryEligible=$pauseRecoveryEligible',
          'windowItems=${_windowItemsText()}',
        ]),
      );
    }
    if ((!_isPlaybackVisible || _pauseWhenOpenCompletes) && isPlaying) {
      unawaited(_session.pause());
      return;
    }
    if (!isPlaying &&
        state.status == PlayerPlaybackStatus.opening &&
        _preparedTakeoverPlayPending &&
        _unexpectedPauseRecoveryDeadline != null) {
      _preparedTakeoverPausedWhileOpening = true;
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
    if (pauseRecoveryEligible) {
      unawaited(
        _enterDecoderPressureMode(
          'current paused while next media session was warming',
        ),
      );
      unawaited(_recoverFromUnexpectedPause());
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
    _updateDecoderPressureStability();
    _syncWatchProgressReportTimer();
  }

  bool _shouldRecoverUnexpectedPause() {
    final deadline = _unexpectedPauseRecoveryDeadline;
    return deadline != null &&
        DateTime.now().isBefore(deadline) &&
        !_userPauseRequested &&
        !_pauseWhenOpenCompletes &&
        !_unexpectedPauseRecoveryInFlight &&
        !state.hasEnded &&
        state.status == PlayerPlaybackStatus.playing &&
        state.currentSource != null;
  }

  Future<void> _recoverFromUnexpectedPause() async {
    if (!_shouldRecoverUnexpectedPause()) {
      return;
    }
    _unexpectedPauseRecoveryInFlight = true;
    final generation = _generation;
    final itemId = state.currentItemId;
    final source = state.currentSource;
    final position = _currentPlaybackPosition;
    // 一个 warm-up 最多只允许修复一次。若仍然失败，会保留清晰 timing 日志，不能在
    // 后台无限 seek/play 造成新的循环。
    _unexpectedPauseRecoveryDeadline = null;
    _logTiming(
      'recover current after prepare interruption',
      itemId: itemId,
      source: source,
      details: _timingDetails([
        'positionMs=${position.inMilliseconds}',
        'reason=unexpected_playing_false_during_prepare_window',
      ]),
    );
    try {
      if (position > Duration.zero) {
        await _seekWithWatchBoundary(position);
      }
      if (!ref.mounted || !_isCurrent(generation) || _userPauseRequested) {
        return;
      }
      await _session.play();
      if (!ref.mounted || !_isCurrent(generation) || _userPauseRequested) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.playing,
        position: position,
        hasEnded: false,
        isBuffering: !state.hasFirstFrame,
      );
      _syncWatchProgressReportTimer();
      _logTiming(
        'recover current after prepare interruption complete',
        itemId: itemId,
        source: source,
        details: 'positionMs=${position.inMilliseconds}',
      );
    } finally {
      _unexpectedPauseRecoveryInFlight = false;
    }
  }

  bool _shouldRecoverPositionRollback(Duration position) {
    final deadline = _unexpectedPauseRecoveryDeadline;
    final lastPosition = _currentPlaybackPosition;
    return deadline != null &&
        DateTime.now().isBefore(deadline) &&
        !_userPauseRequested &&
        !_pauseWhenOpenCompletes &&
        !_positionRollbackRecoveryInFlight &&
        state.status == PlayerPlaybackStatus.playing &&
        lastPosition >= const Duration(seconds: 1) &&
        position < lastPosition - const Duration(milliseconds: 750);
  }

  Future<void> _recoverFromPositionRollback(Duration position) async {
    if (!_shouldRecoverPositionRollback(position)) {
      return;
    }
    _positionRollbackRecoveryInFlight = true;
    unawaited(
      _enterDecoderPressureMode(
        'current position rolled back while next media session was warming',
      ),
    );
    final generation = _generation;
    final itemId = state.currentItemId;
    final source = state.currentSource;
    final repairTarget = _currentPlaybackPosition;
    // 底层 HLS/MediaCodec 可以在没有 Dart open 的情况下回到 0。保留一次修复机会，
    // 把当前位置恢复到回卷前而不是让 UI 和视频重新从开头开始。
    _unexpectedPauseRecoveryDeadline = null;
    _logTiming(
      'recover current after prepare position rollback',
      itemId: itemId,
      source: source,
      details: _timingDetails([
        'reportedPositionMs=${position.inMilliseconds}',
        'repairPositionMs=${repairTarget.inMilliseconds}',
      ]),
    );
    try {
      await _seekWithWatchBoundary(repairTarget);
      if (!ref.mounted || !_isCurrent(generation) || _userPauseRequested) {
        return;
      }
      await _session.play();
      if (!ref.mounted || !_isCurrent(generation) || _userPauseRequested) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.playing,
        position: repairTarget,
        hasEnded: false,
        isBuffering: !state.hasFirstFrame,
      );
      _syncWatchProgressReportTimer();
      _logTiming(
        'recover current after prepare position rollback complete',
        itemId: itemId,
        source: source,
        details: 'positionMs=${repairTarget.inMilliseconds}',
      );
    } finally {
      _positionRollbackRecoveryInFlight = false;
    }
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
    _stopWatchProgressReportTimer();
  }

  void _handlePosition(Duration position) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null || state.isSeeking) {
      return;
    }
    final clamped = _clampToDuration(position);
    _lastNativePlaybackPosition = clamped;
    final restoreFloor = _restoreFloorPosition;
    if (restoreFloor != null &&
        _restoreFloorGeneration == _generation &&
        clamped < restoreFloor - const Duration(milliseconds: 500)) {
      _logTiming(
        'ignore position before restored point',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails([
          'positionMs=${clamped.inMilliseconds}',
          'restoreMs=${restoreFloor.inMilliseconds}',
        ]),
      );
      final repairTarget = _currentPlaybackPosition > restoreFloor
          ? _currentPlaybackPosition
          : restoreFloor;
      _repairResumePositionIfNeeded(repairTarget, _generation, clamped);
      return;
    }
    if (_shouldRecoverPositionRollback(clamped)) {
      unawaited(_recoverFromPositionRollback(clamped));
      return;
    }
    if (_effectiveWatchSeekDepth == 0) {
      _emitEffectiveWatchPosition(clamped);
    }
    final last = _lastPositionUpdate;
    if (last != null &&
        (clamped - last).abs() < const Duration(milliseconds: 250)) {
      return;
    }
    _lastPositionUpdate = clamped;
    _currentPlaybackPosition = clamped;
    _maybeRestoreDecoderWindowAfterStablePlayback();

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
    if (!state.hasFirstFrame && clamped > Duration.zero) {
      _armFirstFrameProgressProbe(
        generation: _generation,
        itemId: state.currentItemId,
        observedPosition: clamped,
      );
    }
    _tryMarkPreloadReadyAfterProgress(clamped);
    state = state.copyWith(
      position: clamped,
      hasFirstFrame: _currentPlaybackHasFirstFrame,
    );
    _saveProgressIfNeeded(position: clamped);
    // 更新字幕显示
    _updateCurrentSubtitle(clamped);
  }

  void _handleDuration(Duration duration) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null) {
      return;
    }
    final normalized = duration < Duration.zero ? Duration.zero : duration;
    final effective = _effectiveDuration(normalized, state.duration);
    _currentPlaybackDuration = effective;
    state = state.copyWith(duration: effective);
    _saveProgressIfNeeded(duration: effective);
  }

  void _applyMetadataDurationFallback(Duration? metadataDuration) {
    final effective = _effectiveDuration(state.duration, metadataDuration);
    if (effective == state.duration) {
      return;
    }
    _currentPlaybackDuration = effective;
    state = state.copyWith(duration: effective);
    _saveProgressIfNeeded(duration: effective);
  }

  void _syncWatchProgressReportTimer() {
    if (!_shouldReportWatchProgressPeriodically) {
      _pauseWatchProgressReportTimer();
      return;
    }
    if (_watchProgressReportTimer?.isActive == true) {
      return;
    }
    final interval = ref.read(playerWatchProgressReportIntervalProvider);
    final remaining = _watchProgressReportRemaining ?? interval;
    final delay = remaining > Duration.zero ? remaining : Duration.zero;
    _watchProgressReportTimerStartedAt = DateTime.now();
    _watchProgressReportTimer = Timer(
      delay,
      _reportPeriodicWatchProgressIfNeeded,
    );
  }

  void _setPlayingStateAndSyncProgressTimer({
    bool? isBuffering,
    bool? hasFirstFrame,
  }) {
    state = state.copyWith(
      status: PlayerPlaybackStatus.playing,
      isBuffering: isBuffering,
      hasFirstFrame: hasFirstFrame,
      hasEnded: false,
    );
    _reportStartWatchProgressIfNeeded();
    _syncWatchProgressReportTimer();
  }

  bool get _shouldReportWatchProgressPeriodically {
    return !_isSessionDisposed &&
        state.status == PlayerPlaybackStatus.playing &&
        state.hasFirstFrame &&
        !state.isBuffering &&
        !state.isSeeking &&
        !state.hasEnded &&
        state.currentItemId != null &&
        state.currentSource != null &&
        _currentPlaybackSource != null &&
        !_pauseWhenOpenCompletes;
  }

  void _reportStartWatchProgressIfNeeded() {
    unawaited(_reportWatchProgress(eventType: 1)); // 1: start
  }

  void _stopWatchProgressReportTimer() {
    _watchProgressReportTimer?.cancel();
    _watchProgressReportTimer = null;
    _watchProgressReportTimerStartedAt = null;
  }

  void _pauseWatchProgressReportTimer() {
    final timer = _watchProgressReportTimer;
    final startedAt = _watchProgressReportTimerStartedAt;
    if (timer?.isActive == true && startedAt != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final Duration remaining =
          _watchProgressReportRemaining ??
          ref.read(playerWatchProgressReportIntervalProvider);
      final nextRemaining = remaining - elapsed;
      _watchProgressReportRemaining = nextRemaining > Duration.zero
          ? nextRemaining
          : Duration.zero;
    }
    _stopWatchProgressReportTimer();
  }

  void _resetWatchProgressReportTimer() {
    _stopWatchProgressReportTimer();
    _watchProgressReportRemaining = ref.read(
      playerWatchProgressReportIntervalProvider,
    );
  }

  void _reportPeriodicWatchProgressIfNeeded() {
    if (!_shouldReportWatchProgressPeriodically) {
      _pauseWatchProgressReportTimer();
      return;
    }
    _stopWatchProgressReportTimer();
    _watchProgressReportRemaining = ref.read(
      playerWatchProgressReportIntervalProvider,
    );
    if (_watchProgressReportInFlight) {
      _syncWatchProgressReportTimer();
      return;
    }
    _watchProgressReportInFlight = true;
    unawaited(
      _reportWatchProgress(eventType: 2).whenComplete(() {
        _watchProgressReportInFlight = false;
        _syncWatchProgressReportTimer();
      }),
    );
  }

  Duration _effectiveDuration(Duration mediaDuration, Duration? fallback) {
    if (mediaDuration > Duration.zero) {
      return mediaDuration;
    }
    if (fallback != null && fallback > Duration.zero) {
      return fallback;
    }
    return Duration.zero;
  }

  Duration _resumeDisplayDuration(
    Duration resumeDuration,
    Duration? itemDuration,
  ) {
    if (itemDuration != null && itemDuration > Duration.zero) {
      return itemDuration;
    }
    return resumeDuration;
  }

  PlaybackProgress? _normalizeResumeProgress(
    PlaybackProgress? progress,
    Duration? itemDuration,
  ) {
    if (progress == null || !progress.canResume) {
      return null;
    }
    final effectiveDuration = _effectiveDuration(Duration.zero, itemDuration);
    if (effectiveDuration <= Duration.zero) {
      return progress;
    }
    final maxSeekPosition = effectiveDuration - const Duration(seconds: 3);
    if (maxSeekPosition <= Duration.zero) {
      _logTiming(
        'resume progress skipped short duration',
        itemId: progress.itemId,
        source: state.currentSource,
        details: _timingDetails([
          'durationMs=${effectiveDuration.inMilliseconds}',
          'resumeMs=${progress.position.inMilliseconds}',
        ]),
      );
      return null;
    }
    final normalizedPosition = progress.position > maxSeekPosition
        ? maxSeekPosition
        : progress.position;
    if (normalizedPosition <= Duration.zero) {
      return null;
    }
    if (normalizedPosition < _resumeOpenStartMinPosition) {
      _logTiming(
        'resume progress skipped near beginning',
        itemId: progress.itemId,
        source: state.currentSource,
        details: _timingDetails([
          'resumeMs=${normalizedPosition.inMilliseconds}',
          'thresholdMs=${_resumeOpenStartMinPosition.inMilliseconds}',
        ]),
      );
      return null;
    }
    if (normalizedPosition != progress.position ||
        effectiveDuration != progress.duration) {
      _logTiming(
        'resume progress normalized',
        itemId: progress.itemId,
        source: state.currentSource,
        details: _timingDetails([
          'fromMs=${progress.position.inMilliseconds}',
          'toMs=${normalizedPosition.inMilliseconds}',
          'durationMs=${effectiveDuration.inMilliseconds}',
        ]),
      );
    }
    return PlaybackProgress(
      itemId: progress.itemId,
      position: normalizedPosition,
      duration: effectiveDuration,
      updatedAt: progress.updatedAt,
    );
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
    // Opening a source can report the engine's default rate before the saved
    // choice is applied. Only an acknowledged preference may update the UI;
    // setPlaybackRate publishes a new choice after setRate succeeds.
    if (rate != _preferredPlaybackRate) {
      return;
    }
    state = state.copyWith(playbackRate: rate);
  }

  void _handleWidth(int? width) {
    if (!ref.mounted) {
      return;
    }
    if (width == null ||
        width <= 0 ||
        state.currentSource == null ||
        state.status == PlayerPlaybackStatus.error) {
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
    _firstFrameProgressProbeTimer?.cancel();
    _firstFrameVideoRecoveryTimer?.cancel();
    _cancelFirstFrameTimeout();
    state = state.copyWith(
      status: state.status == PlayerPlaybackStatus.opening
          ? PlayerPlaybackStatus.playing
          : state.status,
      hasFirstFrame: true,
      isBuffering: false,
    );
    _updateDecoderPressureStability();
    _currentPlaybackHasFirstFrame = true;
    _waitForVideoSurfaceFirstFrameRendered();
    // 首帧仅表示已经有一张可渲染画面，不代表连续分片已经准备充分。下一条预热
    // 必须等当前视频从此处再实际推进一小段，避免在首播 buffer 中抢占网络。
    _preloadReadinessStartPosition ??= _currentPlaybackPosition;
    _syncWatchProgressReportTimer();
    _loadPendingSubtitlesAfterFirstFrame();
    _flushDeferredPreloadAfterFirstFrame(reason: 'first frame');
  }

  void _armFirstFrameProgressProbe({
    required int generation,
    required String? itemId,
    required Duration observedPosition,
  }) {
    if (_firstFrameProgressProbeTimer?.isActive == true || itemId == null) {
      return;
    }
    _firstFrameProgressProbeTimer = Timer(_firstFrameProgressProbeDelay, () {
      if (!ref.mounted ||
          generation != _generation ||
          state.currentItemId != itemId ||
          state.currentSource == null ||
          state.hasFirstFrame ||
          state.position < observedPosition ||
          (state.status != PlayerPlaybackStatus.playing &&
              state.status != PlayerPlaybackStatus.paused)) {
        return;
      }
      _logTiming(
        'playback progress sustained before first frame',
        itemId: itemId,
        source: state.currentSource,
        details: _timingDetails([
          'positionMs=${state.position.inMilliseconds}',
          'observedPositionMs=${observedPosition.inMilliseconds}',
        ]),
      );
    });
    _armFirstFrameVideoRecovery(
      generation: generation,
      itemId: itemId,
      observedPosition: observedPosition,
    );
  }

  /// 个别 Android/HLS 会先持续推进音频时钟，却迟迟收不到 video width。此时继续
  /// 等完整 8 秒首帧超时只会让用户多看一段 loading。确认已推进且 1.4 秒仍无视频
  /// 后，仅重开一次同一 source；已下载的 playlist/segment 会命中内存/磁盘缓存。
  void _armFirstFrameVideoRecovery({
    required int generation,
    required String itemId,
    required Duration observedPosition,
  }) {
    if (sessionKey == PlayerPlaybackSessionKeys.forYouTab ||
        _firstFrameVideoRecoveryAttempted ||
        _firstFrameVideoRecoveryTimer?.isActive == true) {
      return;
    }
    _firstFrameVideoRecoveryTimer = Timer(_firstFrameVideoRecoveryDelay, () {
      if (!ref.mounted ||
          !_isCurrent(generation) ||
          state.currentItemId != itemId ||
          state.currentSource == null ||
          state.hasFirstFrame ||
          state.position < observedPosition ||
          state.status == PlayerPlaybackStatus.paused ||
          state.status == PlayerPlaybackStatus.error) {
        return;
      }
      final item = _currentOriginalItem;
      if (item == null || item.id != itemId) {
        return;
      }
      _firstFrameVideoRecoveryAttempted = true;
      unawaited(
        _enterDecoderPressureMode(
          'audio advanced but video first frame was unavailable',
        ),
      );
      _logTiming(
        'first frame video recovery reopen',
        itemId: itemId,
        source: state.currentSource,
        details: _timingDetails([
          'positionMs=${state.position.inMilliseconds}',
          'observedPositionMs=${observedPosition.inMilliseconds}',
          'delayMs=${_firstFrameVideoRecoveryDelay.inMilliseconds}',
        ]),
      );
      unawaited(playItem(item, forceReopen: true));
    });
  }

  void _flushDeferredPreloadAfterFirstFrame({String reason = 'first frame'}) {
    final items = _deferredPreloadItems;
    final index = _deferredPreloadIndex;
    if (items == null || index == null) {
      return;
    }
    if (!ref.mounted ||
        _isSessionDisposed ||
        index < 0 ||
        index >= items.length ||
        items[index].id != state.currentItemId) {
      return;
    }
    if (!_preloadReadinessReached || state.isBuffering) {
      _logTiming(
        'preload deferred awaiting stable playback',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails([
          'reason=$reason',
          'hasFirstFrame=${state.hasFirstFrame}',
          'isBuffering=${state.isBuffering}',
          'positionMs=${state.position.inMilliseconds}',
          'baselineMs=${_preloadReadinessStartPosition?.inMilliseconds ?? -1}',
          'requiredAdvanceMs=${_preloadReadinessAdvance.inMilliseconds}',
        ]),
      );
      return;
    }
    _deferredPreloadItems = null;
    _deferredPreloadIndex = null;
    _logTiming(
      'preload deferred flush',
      itemId: state.currentItemId,
      source: state.currentSource,
      details: _timingDetails([
        'reason=$reason',
        'currentIndex=$index',
        'itemCount=${items.length}',
      ]),
    );
    unawaited(preloadAround(items, index));
  }

  void _tryMarkPreloadReadyAfterProgress(Duration position) {
    if (!state.hasFirstFrame || state.isBuffering || _preloadReadinessReached) {
      return;
    }
    final baseline = _preloadReadinessStartPosition ??= position;
    if (position < baseline + _preloadReadinessAdvance) {
      return;
    }
    _preloadReadinessReached = true;
    _logTiming(
      'playback stable for deferred preload',
      itemId: state.currentItemId,
      source: state.currentSource,
      details: _timingDetails([
        'positionMs=${position.inMilliseconds}',
        'baselineMs=${baseline.inMilliseconds}',
        'advanceMs=${(position - baseline).inMilliseconds}',
      ]),
    );
    _flushDeferredPreloadAfterFirstFrame(reason: 'stable playback');
  }

  void _handleError(String error) {
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null) {
      return;
    }
    final errorKind = _classifyPlaybackError(error);
    _logTiming(
      'error',
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
    _markPlaybackFailed(error: error, errorKind: errorKind);
  }

  void _armFirstFrameTimeout({
    required int generation,
    required PlayerFeedItem item,
  }) {
    _cancelFirstFrameTimeout();
    final timeout = ref.read(playerFirstFrameTimeoutProvider);
    if (timeout <= Duration.zero) return;
    _firstFrameTimeoutTimer = Timer(timeout, () {
      if (!ref.mounted ||
          !_isCurrent(generation) ||
          state.currentItemId != item.id ||
          state.currentSource == null ||
          state.hasFirstFrame ||
          state.status == PlayerPlaybackStatus.error ||
          state.status == PlayerPlaybackStatus.paused) {
        return;
      }
      final error = TimeoutException(
        'Timed out waiting for the first video frame after '
        '${timeout.inMilliseconds}ms.',
      );
      _logTiming(
        'first frame timeout',
        itemId: item.id,
        source: state.currentSource,
        error: error,
      );
      if (state.position > Duration.zero ||
          _playingBeforeFirstFrameAt != null) {
        unawaited(
          _enterDecoderPressureMode(
            'first frame timed out after playback had started',
          ),
        );
      }
      if (_shouldAutoRetryFirstFrameTimeout(item)) {
        _firstFrameAutoRetryItemId = item.id;
        _logTiming(
          'first-frame timeout auto retry',
          itemId: item.id,
          source: state.currentSource,
          details:
              'reason=first_frame_timeout maxAttempts=1 mode=${item.mode.name}',
        );
        if (sessionKey == PlayerPlaybackSessionKeys.forYouTab) {
          // For You may keep its widget alive in an IndexedStack while the
          // native Android decoder/Surface is already unusable. Reopening the
          // same session leaves that failure black forever; create a fresh
          // native session instead.
          unawaited(
            recoverForYouPlaybackIfFailed(
              item,
              trigger: 'first_frame_timeout',
              forceRebuild: true,
            ),
          );
          return;
        }
        unawaited(playItem(item, forceReopen: true));
        return;
      }
      _markPlaybackFailed(
        error: error,
        errorKind: PlayerPlaybackErrorKind.unknown,
        expectedGeneration: generation,
      );
    });
  }

  bool _shouldAutoRetryFirstFrameTimeout(PlayerFeedItem item) {
    return _firstFrameAutoRetryItemId != item.id &&
        state.currentItemId == item.id &&
        state.currentSource != null &&
        !state.hasFirstFrame &&
        state.status != PlayerPlaybackStatus.paused;
  }

  void _cancelFirstFrameTimeout() {
    _firstFrameTimeoutTimer?.cancel();
    _firstFrameTimeoutTimer = null;
  }

  /// 收敛所有播放失败出口。保留 currentSource 让 UI 继续挂载错误覆盖层，同时
  /// 使当前 generation 失效，防止晚到的 open/playing/width 事件把错误态改回播放。
  void _markPlaybackFailed({
    required Object error,
    required PlayerPlaybackErrorKind errorKind,
    int? expectedGeneration,
  }) {
    if (!ref.mounted ||
        state.currentSource == null ||
        (expectedGeneration != null && !_isCurrent(expectedGeneration))) {
      return;
    }
    _generation += 1;
    _cancelFirstFrameTimeout();
    _firstFrameProgressProbeTimer?.cancel();
    _stopWatchProgressReportTimer();
    _currentPlaybackItemId = null;
    _currentPlaybackSource = null;
    _clearCurrentPlaybackSnapshot();
    state = state.copyWith(
      status: PlayerPlaybackStatus.error,
      hasFirstFrame: false,
      hasRenderedFirstFrame: false,
      isBuffering: false,
      error: error,
      errorKind: errorKind,
    );
    unawaited(_session.pause());
  }

  PlayerPlaybackErrorKind _classifyPlaybackError(String error) {
    final normalized = error.toLowerCase();
    // 明确的 HTTP 4xx 表示 source、签名或权限有问题，不是播放器重试即可恢复的
    // 短暂网络抖动。必须先于 `.ts` / `segment` 判断，否则失败的 HLS 分片会被误判
    // 为 recoverable，导致黑屏时 position 和字幕仍继续推进。
    if (normalized.contains('400') ||
        normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('404')) {
      return PlayerPlaybackErrorKind.sourceResolve;
    }
    if (normalized.contains('tcp') ||
        normalized.contains('ffurl') ||
        normalized.contains('segment') ||
        normalized.contains('.ts') ||
        normalized.contains('connection') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return PlayerPlaybackErrorKind.recoverableNetwork;
    }
    if (normalized.contains('source') || normalized.contains('resolve')) {
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
    _stopWatchProgressReportTimer();
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
    _stopWatchProgressReportTimer();
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
    ++_effectiveWatchGeneration;
    _emitEffectiveWatchPosition(null);
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

  /// Recreates only the current session after media_kit proves its native
  /// Player has already been disposed. This is deliberately a narrow recovery
  /// path: normal source/decoder errors must not silently create another
  /// player, while a disposed player can never recover by reopening it.
  Future<bool> _replaceDisposedSessionForOpen(int generation) async {
    if (!ref.mounted || !_isCurrent(generation) || _isSessionDisposed) {
      return false;
    }
    final cancelOldStreams = _cancelSessionStreams();
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _attachSessionStreams(_session);
    // Publish the replacement before awaiting listener cancellation. The
    // currently mounted Video widget then receives a fresh controller instead
    // of subscribing again to the disposed controller from the failed session.
    state = state.copyWith(
      videoController: _session.videoController,
      surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
    );
    _logTiming(
      'create current session',
      details: 'reason=recover disposed player before open',
    );
    await cancelOldStreams;
    return ref.mounted && _isCurrent(generation) && !_isSessionDisposed;
  }

  bool _isDisposedPlayerError(Object error) =>
      error is AssertionError &&
      error.toString().contains('[Player] has been disposed');

  bool _isLocalHlsProxySource(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'http') {
      return false;
    }
    return uri.host == 'localhost' || uri.host == '127.0.0.1';
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
    await _session.setRate(_preferredPlaybackRate);
    _currentPlaybackSource = prepared.source;
    _currentPlaybackItemId = prepared.itemId;
    _attachSessionStreams(_session);
    await previousSession.pause();
    final preloadConfig = ref.read(playerPreloadConfigProvider);
    if (_shouldConstrainNativeDecoderWindow) {
      final released = await _releaseRetainedSessionsForDecoderPressure();
      await previousSession.dispose();
      _logTiming(
        'dispose current session',
        itemId: previousItemId,
        source: previousSource?.playableSource,
        details: _timingDetails([
          'reason=${_decoderPressureReason ?? 'decoder pressure'}',
          'releasedRetained=${released.join(',')}',
        ]),
      );
    } else if (previousSource != null &&
        previousItemId != null &&
        preloadConfig.effectiveRetainedBackwardSessionCount > 0) {
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
    if (_shouldConstrainNativeDecoderWindow) {
      final released = await _releaseRetainedSessionsForDecoderPressure();
      _logTiming(
        'retain current skipped',
        itemId: _currentPlaybackItemId,
        source: _currentPlaybackSource?.playableSource,
        details: _timingDetails([
          'reason=${_decoderPressureReason ?? 'decoder pressure'}',
          'releasedRetained=${released.join(',')}',
        ]),
      );
      return false;
    }
    if (ref
            .read(playerPreloadConfigProvider)
            .effectiveRetainedBackwardSessionCount ==
        0) {
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
      if (_shouldConstrainNativeDecoderWindow) {
        final released = await _releaseRetainedSessionsForDecoderPressure();
        if (!ref.mounted || _isSessionDisposed) {
          return;
        }
        if (released.isNotEmpty) {
          _logTiming(
            'decoder window constrained before prepare',
            itemId: state.currentItemId,
            source: state.currentSource,
            details: _timingDetails([
              'reason=${_decoderPressureReason ?? 'decoder pressure'}',
              'releasedRetained=${released.join(',')}',
            ]),
          );
        }
      }
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
        maxVideoHeight: _automaticVideoHeightCap(),
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
      if (prepared != null && _shouldConstrainNativeDecoderWindow) {
        final released = await _releaseRetainedSessionsForDecoderPressure();
        if (released.isNotEmpty) {
          _logTiming(
            'decoder window constrained after prepare',
            itemId: item.id,
            source: prepared.source.playableSource,
            details: _timingDetails([
              'reason=${_decoderPressureReason ?? 'decoder pressure'}',
              'releasedRetained=${released.join(',')}',
            ]),
          );
        }
      }
      if (prepared != null &&
          state.currentItemId != null &&
          state.currentSource != null &&
          state.status == PlayerPlaybackStatus.playing) {
        // 从 prepare 真正创建第二个解码 session 开始，到其首帧 pause 后的短时间，
        // 是 Android 厂商 codec 最容易错误暂停 current 的窗口。只在此窗口开启一次
        // current 修复，不改变正常的用户暂停、路由切换或自然完播行为。
        _unexpectedPauseRecoveryDeadline = DateTime.now().add(
          const Duration(seconds: 12),
        );
        _logTiming(
          'prepare interruption guard armed',
          itemId: state.currentItemId,
          source: state.currentSource,
          details: _timingDetails([
            'preparedItemId=${prepared.itemId}',
            'guardMs=12000',
          ]),
        );
      }
    } finally {
      _preparingItemIds.remove(item.id);
    }
  }

  Future<void> _restoreProgressIfNeeded(
    PlaybackProgress? progress,
    int generation,
  ) async {
    developer.log(
      '_restoreProgressIfNeeded: progress=$progress, '
      'canResume=${progress?.canResume}, '
      '_shouldPersistProgress=$_shouldPersistProgress',
    );
    if (progress == null || !progress.canResume || !_shouldPersistProgress) {
      developer.log(
        '_restoreProgressIfNeeded: 不恢复 - '
        'progress==null:${progress == null}, '
        'canResume:${progress?.canResume}, '
        '_shouldPersistProgress:$_shouldPersistProgress',
      );
      return;
    }
    developer.log(
      '_restoreProgressIfNeeded: 开始恢复播放，seek 到 ${progress.position.inSeconds}s',
    );

    if (state.hasEnded) {
      _logTiming(
        'resume progress skipped after ended',
        itemId: state.currentItemId,
        source: state.currentSource,
      );
      return;
    }
    if (_lastAppliedResumeGeneration == generation &&
        _lastAppliedResumeItemId == progress.itemId &&
        _lastAppliedResumePosition == progress.position) {
      _logTiming(
        'resume progress skipped duplicate',
        itemId: progress.itemId,
        source: state.currentSource,
        details: _timingDetails([
          'positionMs=${progress.position.inMilliseconds}',
        ]),
      );
      return;
    }
    final currentPosition = _currentPlaybackPosition > Duration.zero
        ? _currentPlaybackPosition
        : state.position;
    if (currentPosition > progress.position + const Duration(seconds: 1)) {
      _logTiming(
        'resume progress skipped stale',
        itemId: progress.itemId,
        source: state.currentSource,
        details: _timingDetails([
          'currentMs=${currentPosition.inMilliseconds}',
          'resumeMs=${progress.position.inMilliseconds}',
        ]),
      );
      return;
    }
    _lastAppliedResumeGeneration = generation;
    _lastAppliedResumeItemId = progress.itemId;
    _lastAppliedResumePosition = progress.position;
    _armRestoreFloor(progress.position, generation);
    await _seekWithWatchBoundary(progress.position);
    if (!ref.mounted || !_isCurrent(generation)) {
      return;
    }
    state = state.copyWith(
      position: progress.position,
      duration: progress.duration > Duration.zero
          ? _resumeDisplayDuration(progress.duration, state.duration)
          : state.duration,
      bufferedPosition: state.bufferedPosition < progress.position
          ? progress.position
          : state.bufferedPosition,
    );
    _currentPlaybackPosition = progress.position;
    if (progress.duration > Duration.zero) {
      _currentPlaybackDuration = _resumeDisplayDuration(
        progress.duration,
        state.duration,
      );
    }
    if (_currentPlaybackBufferedPosition < progress.position) {
      _currentPlaybackBufferedPosition = progress.position;
    }

    // 恢复进度后，更新字幕显示位置
    _updateCurrentSubtitle(progress.position);
    unawaited(_confirmRestoreSeek(progress.position, generation));
  }

  void _armRestoreFloor(Duration position, int generation) {
    _restoreFloorTimer?.cancel();
    _restoreFloorPosition = position;
    _restoreFloorGeneration = generation;
    _restoreFloorTimer = Timer(_restoreFloorTimeout, () {
      if (_restoreFloorGeneration != generation) {
        return;
      }
      _restoreFloorPosition = null;
    });
  }

  void _repairResumePositionIfNeeded(
    Duration target,
    int generation,
    Duration current,
  ) {
    if (_resumeGuardRepairing ||
        _resumeGuardRepairAttempts >= 2 ||
        _isSessionDisposed ||
        !_isCurrent(generation)) {
      return;
    }
    _resumeGuardRepairing = true;
    _resumeGuardRepairAttempts += 1;
    developer.log(
      'PlayerPlaybackController: resume guard repair '
      'attempt=$_resumeGuardRepairAttempts, current=$current, target=$target',
    );
    unawaited(() async {
      try {
        _armRestoreFloor(target, generation);
        await _seekWithWatchBoundary(target);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!ref.mounted || !_isCurrent(generation) || _isSessionDisposed) {
          return;
        }
      } catch (error) {
        _logTiming(
          'resume guard repair error',
          itemId: state.currentItemId,
          source: state.currentSource,
          error: error,
        );
      } finally {
        _resumeGuardRepairing = false;
      }
    }());
  }

  Future<void> _confirmRestoreSeek(Duration position, int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!ref.mounted || !_isCurrent(generation) || _isSessionDisposed) {
      return;
    }
    final currentPosition = _lastNativePlaybackPosition;
    if (state.hasEnded ||
        (currentPosition > Duration.zero &&
            currentPosition >= position - const Duration(milliseconds: 250))) {
      _logTiming(
        'resume confirm seek skipped',
        itemId: state.currentItemId,
        source: state.currentSource,
        details: _timingDetails([
          'currentMs=${currentPosition.inMilliseconds}',
          'resumeMs=${position.inMilliseconds}',
          'hasEnded=${state.hasEnded}',
        ]),
      );
      return;
    }
    await _seekWithWatchBoundary(position);
    if (!ref.mounted || !_isCurrent(generation)) {
      return;
    }
    _armRestoreFloor(position, generation);
    state = state.copyWith(
      position: position,
      bufferedPosition: state.bufferedPosition < position
          ? position
          : state.bufferedPosition,
    );
    _currentPlaybackPosition = position;
    if (_currentPlaybackBufferedPosition < position) {
      _currentPlaybackBufferedPosition = position;
    }
  }

  bool _usesCurrentMediaSource(PlayerFeedItem item) {
    final candidate = item.episode.videoSource;
    if (candidate == null || state.currentItemId != item.id) {
      return false;
    }
    final currentSource = _currentPlaybackSource;
    return candidate == state.currentSource ||
        candidate == currentSource?.remoteUrl ||
        candidate == currentSource?.playableSource;
  }

  bool _isStaleResumeProgress(PlaybackProgress progress) {
    if (!progress.canResume || state.currentItemId != progress.itemId) {
      return false;
    }
    final currentPosition = _currentPlaybackPosition > Duration.zero
        ? _currentPlaybackPosition
        : state.position;
    return state.hasEnded ||
        currentPosition > progress.position + const Duration(seconds: 1);
  }

  Future<PlaybackProgress?> _resumeProgressForItem(String itemId) async {
    _lastResumeProgressWasPending = false;
    _lastResumeProgressRequiresSeekAfterOpen = false;
    final pending = _pendingResumeProgress;
    if (pending != null) {
      if (pending.itemId == itemId) {
        _pendingResumeProgress = null;
        _lastResumeProgressWasPending = true;
        _lastResumeProgressRequiresSeekAfterOpen =
            _pendingResumeProgressRequiresSeekAfterOpen;
        _pendingResumeProgressRequiresSeekAfterOpen = false;
        return pending;
      }
      _logTiming(
        'resume progress pending kept for different item',
        itemId: itemId,
        details: _timingDetails([
          'pendingItemId=${pending.itemId}',
          'requestedItemId=$itemId',
        ]),
      );
      return null;
    }
    if (!_shouldPersistProgress) {
      return null;
    }
    try {
      return await _progressRepository
          .getProgress(itemId)
          .timeout(_localResumeReadBudget);
    } on TimeoutException {
      _logTiming(
        'resume progress read timeout',
        itemId: itemId,
        details: 'budgetMs=${_localResumeReadBudget.inMilliseconds}',
      );
      return null;
    }
  }

  /// 加载指定 item 的字幕列表。
  ///
  /// 在 [playItem] 中调用，会在成功打开 source 后自动加载默认字幕。
  void _loadSubtitlesForItem(PlayerFeedItem item) {
    final subtitles = item.episode.subtitles;
    final episodeSources = item.episode.episodeSources;
    if (subtitles.isEmpty) {
      state = state.copyWith(
        availableSubtitles: const [],
        availableEpisodeSources: episodeSources,
        subtitleCues: const [],
        currentSubtitleText: '',
        clearSubtitle: true,
        isSubtitleSelectionResolved: true,
      );
      return;
    }

    state = state.copyWith(
      availableSubtitles: subtitles,
      availableEpisodeSources: episodeSources,
      isSubtitleSelectionResolved: false,
    );

    // 有内嵌字幕视频时，语言选择和视频源始终以 episode_sources 为准。外挂
    // 字幕只作为当前内嵌语言的补充，不能沿用上一集“关闭外挂字幕”的状态。
    if (episodeSources.isNotEmpty) {
      _externalSubtitlesClosed = false;
      final source = _selectEpisodeSourceForCurrentLanguage(episodeSources);
      _preferredSubtitleLanguage = _episodeSourceMatchCode(source);
      final external = _findSubtitleForEpisodeSource(subtitles, source);
      state = state.copyWith(
        currentSubtitleLanguage: _episodeSourceMatchCode(source),
      );
      if (external == null) {
        state = state.copyWith(
          clearSubtitle: true,
          subtitleCues: const [],
          currentSubtitleText: '',
          isSubtitleSelectionResolved: true,
        );
        return;
      }
      if (!state.hasFirstFrame) {
        _pendingSubtitleLoadItem = item;
        _logTiming(
          'subtitle external load deferred until first frame',
          itemId: item.id,
          source: state.currentSource,
        );
        return;
      }
      unawaited(
        _setExternalSubtitle(external, updateCurrentSubtitleLanguage: false),
      );
      return;
    }

    if (_externalSubtitlesClosed) {
      unawaited(setSubtitle(null));
      return;
    }

    final selected = _selectSubtitleForCurrentLanguage(subtitles);
    _preferredSubtitleLanguage = _subtitleMatchCode(selected);
    // 字幕文件会在首帧后异步加载；在此提前记录已预选语言，供 UI 和埋点在
    // 实际播放开始时读取，不能把“加载中”误判成用户关闭字幕。
    state = state.copyWith(
      currentSubtitleLanguage: _subtitleMatchCode(selected),
    );
    if (!state.hasFirstFrame) {
      _pendingSubtitleLoadItem = item;
      _logTiming(
        'subtitle external load deferred until first frame',
        itemId: item.id,
        source: state.currentSource,
      );
      return;
    }
    unawaited(_setExternalSubtitle(selected));
  }

  void _loadPendingSubtitlesAfterFirstFrame() {
    final item = _pendingSubtitleLoadItem;
    if (item == null || item.id != state.currentItemId) {
      _pendingSubtitleLoadItem = null;
      return;
    }
    _pendingSubtitleLoadItem = null;
    _logTiming(
      'subtitle external load deferred flush',
      itemId: item.id,
      source: state.currentSource,
    );
    _loadSubtitlesForItem(item);
  }

  /// 切换当前字幕轨道。
  ///
  /// [subtitleUrl] 为 `null` 时关闭字幕。
  /// 公开方法，供 UI 层字幕选择器调用。
  Future<void> setSubtitle(String? subtitleUrl) async {
    if (subtitleUrl == null) {
      _externalSubtitlesClosed = true;
      // 关闭字幕 - 使用 clearSubtitle 确保 currentSubtitleUrl 被正确设置为 null
      state = state.copyWith(
        clearSubtitle: true,
        subtitleCues: const [],
        currentSubtitleText: '',
        clearSubtitleLanguage: true,
        isSubtitleSelectionResolved: true,
      );
      developer.log('setSubtitle: 已关闭字幕');
      return;
    }

    PlayerSubtitle? selected;
    for (final subtitle in state.availableSubtitles) {
      if (subtitle.url == subtitleUrl) {
        selected = subtitle;
        break;
      }
    }
    if (selected != null) {
      _externalSubtitlesClosed = false;
      _preferredSubtitleLanguage = _subtitleMatchCode(selected);
      await _setExternalSubtitle(selected);
      return;
    }

    // 先保存旧的 URL，用于失败回滚
    final oldUrl = state.currentSubtitleUrl;
    state = state.copyWith(currentSubtitleUrl: subtitleUrl);
    developer.log('setSubtitle: 开始切换字幕 - $subtitleUrl');

    try {
      await _fetchAndParseSubtitle(subtitleUrl);
      developer.log('setSubtitle: 字幕切换成功 - $subtitleUrl');
    } catch (e, st) {
      // 字幕加载失败，回滚状态
      developer.log('setSubtitle: 字幕加载失败，回滚状态 - $e\n$st');
      state = state.copyWith(
        currentSubtitleUrl: oldUrl,
        subtitleCues: const [],
        currentSubtitleText: '',
      );
    }
  }

  Future<void> _setExternalSubtitle(
    PlayerSubtitle subtitle, {
    bool updateCurrentSubtitleLanguage = true,
  }) async {
    final oldUrl = state.currentSubtitleUrl;
    state = state.copyWith(
      currentSubtitleUrl: subtitle.url,
      currentSubtitleLanguage: updateCurrentSubtitleLanguage
          ? _subtitleMatchCode(subtitle)
          : null,
      currentSubtitlePosition: subtitle.position,
      isSubtitleSelectionResolved: true,
    );
    try {
      await _fetchAndParseSubtitle(subtitle.url, format: subtitle.format);
    } catch (e, st) {
      developer.log('setSubtitle: 字幕加载失败，回滚状态 - $e\n$st');
      state = state.copyWith(
        currentSubtitleUrl: oldUrl,
        subtitleCues: const [],
        currentSubtitleText: '',
      );
    }
  }

  /// 根据 language 切换外挂字幕或带内嵌字幕的视频资源。
  Future<void> selectSubtitleLanguage(String language) async {
    final operation = ++_sourceSwitchOperation;
    final sources = state.availableEpisodeSources;
    if (sources.isEmpty) {
      final external = _findSubtitle(state.availableSubtitles, language);
      if (external == null) return;
      _externalSubtitlesClosed = false;
      _preferredSubtitleLanguage = _subtitleMatchCode(external);
      await _setExternalSubtitle(external);
      if (!_isCurrentSourceSwitch(operation)) return;
      return;
    }

    final source = _findEpisodeSource(sources, language);
    final item = _currentOriginalItem;
    if (source == null || item == null) return;

    final position = state.position;
    _preferredSubtitleLanguage = _episodeSourceMatchCode(source);
    _externalSubtitlesClosed = false;
    state = state.copyWith(
      currentSubtitleLanguage: _episodeSourceMatchCode(source),
    );
    await _disposePreloads();
    if (!_isCurrentSourceSwitch(operation)) return;
    await _releaseSessionWindowFor('embedded subtitle language changed');
    if (!_isCurrentSourceSwitch(operation)) return;
    if (position > Duration.zero) {
      _pendingResumeProgress = PlaybackProgress(
        itemId: item.id,
        position: position,
        duration: state.duration,
        updatedAt: DateTime.now(),
      );
    }
    _lastPlayItemRequest = null;
    await playItem(item);
    if (!_isCurrentSourceSwitch(operation)) return;
  }

  bool _isCurrentSourceSwitch(int operation) =>
      ref.mounted && !_isSessionDisposed && operation == _sourceSwitchOperation;

  PlayerFeedItem _itemUsingPreferredEmbeddedSource(
    PlayerFeedItem item, {
    bool updatePreference = true,
  }) {
    final sources = item.episode.episodeSources;
    if (sources.isEmpty) return item;
    final selected = _selectEpisodeSourceForCurrentLanguage(sources);
    if (updatePreference) {
      _preferredSubtitleLanguage = _episodeSourceMatchCode(selected);
    }
    return item.copyWith(
      episode: item.episode.copyWith(videoUrl: selected.url),
    );
  }

  PlayerSubtitle? _findSubtitle(
    List<PlayerSubtitle> subtitles,
    String? language,
  ) {
    return _findByLanguage(
      subtitles,
      language,
      (subtitle) => _subtitleMatchCode(subtitle),
      fallbackLanguageOf: (subtitle) => subtitle.language,
    );
  }

  /// 内嵌视频和外挂字幕的关联只使用接口下发的 language_code；语言名称仅用于
  /// UI 展示，不能参与匹配，避免同名语言被错误地绑定到另一个视频源。
  PlayerSubtitle? _findSubtitleForEpisodeSource(
    List<PlayerSubtitle> subtitles,
    PlayerEpisodeSource source,
  ) {
    final sourceCode = _normalizeLanguage(source.languageCode);
    if (sourceCode.isEmpty) return null;
    for (final subtitle in subtitles) {
      if (_normalizeLanguage(subtitle.languageCode) == sourceCode) {
        return subtitle;
      }
    }
    return null;
  }

  PlayerEpisodeSource? _findEpisodeSource(
    List<PlayerEpisodeSource> sources,
    String? language,
  ) {
    return _findByLanguage(
      sources,
      language,
      (source) => _episodeSourceMatchCode(source),
      fallbackLanguageOf: (source) => source.language,
    );
  }

  PlayerSubtitle _selectSubtitleForCurrentLanguage(
    List<PlayerSubtitle> subtitles,
  ) {
    return _findSubtitle(subtitles, _preferredSubtitleLanguage) ??
        _findSubtitle(subtitles, _appSubtitleLanguageCode()) ??
        subtitles.first;
  }

  PlayerEpisodeSource _selectEpisodeSourceForCurrentLanguage(
    List<PlayerEpisodeSource> sources,
  ) {
    return _findEpisodeSource(sources, _preferredSubtitleLanguage) ??
        _findEpisodeSource(sources, _appSubtitleLanguageCode()) ??
        sources.first;
  }

  T? _findByLanguage<T>(
    List<T> items,
    String? language,
    String Function(T item) languageOf, {
    String Function(T item)? fallbackLanguageOf,
  }) {
    if (language == null) return null;
    final normalized = _normalizeLanguage(language);
    for (final item in items) {
      if (_normalizeLanguage(languageOf(item)) == normalized) return item;
      final fallback = fallbackLanguageOf;
      if (fallback != null &&
          _normalizeLanguage(fallback(item)) == normalized) {
        return item;
      }
    }
    return null;
  }

  String _normalizeLanguage(String value) => value.trim().toLowerCase();

  String _subtitleMatchCode(PlayerSubtitle subtitle) {
    return subtitle.languageCode.isNotEmpty
        ? subtitle.languageCode
        : subtitle.language;
  }

  String _episodeSourceMatchCode(PlayerEpisodeSource source) {
    return source.languageCode.isNotEmpty
        ? source.languageCode
        : source.language;
  }

  String _appSubtitleLanguageCode() {
    return apiLangFromLocale(ref.read(appLocaleControllerProvider));
  }

  String? _subtitleLanguageCodeForEpisodeSource(PlayerEpisode episode) {
    for (final source in episode.episodeSources) {
      if (source.url == episode.videoUrl) {
        return _episodeSourceMatchCode(source);
      }
    }
    return null;
  }

  /// 从网络获取并解析字幕文件。
  ///
  /// 包含重试机制和超时处理，最多重试 3 次。
  Future<void> _fetchAndParseSubtitle(String url, {String? format}) async {
    const maxRetries = 3;
    const timeout = Duration(seconds: 10);

    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        developer.log('_fetchAndParseSubtitle: 尝试下载字幕 (第 $attempt 次) - $url');

        final response = await http.get(Uri.parse(url)).timeout(timeout);

        if (response.statusCode != 200) {
          developer.log(
            '_fetchAndParseSubtitle: HTTP ${response.statusCode} for $url (第 $attempt 次)',
          );

          // 如果是客户端错误（4xx），不重试
          if (response.statusCode >= 400 && response.statusCode < 500) {
            developer.log('_fetchAndParseSubtitle: 客户端错误，不再重试');
            return;
          }

          // 如果是服务器错误（5xx），继续重试
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt)); // 指数退避
            continue;
          }
          return;
        }

        final cues = SubtitleParser.parse(
          content: utf8.decode(response.bodyBytes),
          format: format?.toLowerCase() ?? _guessFormatFromUrl(url),
        );

        if (!ref.mounted) return;
        state = state.copyWith(subtitleCues: cues);

        // 立即更新当前位置对应的字幕
        _updateCurrentSubtitle(state.position);

        developer.log('_fetchAndParseSubtitle: 字幕解析成功，共 ${cues.length} 条');
        return; // 成功，退出重试循环
      } on TimeoutException catch (e) {
        developer.log('_fetchAndParseSubtitle: 超时 (第 $attempt 次) - $e');
        if (attempt == maxRetries) {
          developer.log('_fetchAndParseSubtitle: 已达到最大重试次数，放弃下载');
          return;
        }
      } on http.ClientException catch (e) {
        developer.log('_fetchAndParseSubtitle: 网络错误 (第 $attempt 次) - $e');
        if (attempt == maxRetries) {
          developer.log('_fetchAndParseSubtitle: 已达到最大重试次数，放弃下载');
          return;
        }
        // 等待后重试
        await Future.delayed(Duration(seconds: attempt));
      } catch (e, st) {
        developer.log('_fetchAndParseSubtitle: 未知错误 (第 $attempt 次) - $e\n$st');
        if (attempt == maxRetries) {
          return;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
  }

  /// 根据当前播放位置更新应显示的字幕文本。
  ///
  /// 应在 position stream 和 seek 后调用。
  void _updateCurrentSubtitle(Duration position) {
    final cues = state.subtitleCues;
    if (cues.isEmpty) return;

    // 二分查找当前位置对应的字幕
    var low = 0;
    var high = cues.length - 1;
    SubtitleCue? currentCue;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final cue = cues[mid];
      if (position >= cue.start && position <= cue.end) {
        currentCue = cue;
        break;
      } else if (position < cue.start) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    final newText = currentCue?.text ?? '';
    if (state.currentSubtitleText != newText) {
      state = state.copyWith(currentSubtitleText: newText);
    }
  }

  /// 根据 URL 猜测字幕格式。
  String _guessFormatFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.srt')) return 'srt';
    return 'vtt'; // 默认 VTT
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
    final itemId = state.currentItemId!;
    if (!_shouldSaveProgressSnapshot(itemId, nextPosition, nextDuration)) {
      return;
    }
    _markProgressSnapshotSaved(itemId, nextPosition, nextDuration);
    unawaited(
      _progressRepository.saveProgress(
        PlaybackProgress(
          itemId: itemId,
          position: nextPosition,
          duration: nextDuration,
          updatedAt: DateTime.now(),
        ),
      ),
    );
    final item = _currentOriginalItem;
    if (item != null &&
        item.id == itemId &&
        item.mode == PlayerFeedMode.singleDrama) {
      unawaited(
        _dramaPlaybackTargetRepository.save(
          DramaPlaybackTarget(
            dramaId: item.content.id,
            episodeId: item.episode.id,
            position: nextPosition,
            duration: nextDuration,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }
  }

  bool _shouldSaveProgressSnapshot(
    String itemId,
    Duration position,
    Duration duration,
  ) {
    final lastSaveAt = _lastProgressSaveAt;
    final lastItemId = _lastSavedProgressItemId;
    final lastPosition = _lastSavedProgressPosition;
    final lastDuration = _lastSavedProgressDuration;
    if (lastSaveAt == null ||
        lastItemId != itemId ||
        lastPosition == null ||
        lastDuration == null ||
        lastDuration != duration) {
      return true;
    }
    final elapsed = DateTime.now().difference(lastSaveAt);
    final positionDelta = (position - lastPosition).abs();
    return elapsed >= const Duration(seconds: 3) ||
        positionDelta >= const Duration(seconds: 3);
  }

  void _markProgressSnapshotSaved(
    String itemId,
    Duration position,
    Duration duration,
  ) {
    _lastProgressSaveAt = DateTime.now();
    _lastSavedProgressItemId = itemId;
    _lastSavedProgressPosition = position;
    _lastSavedProgressDuration = duration;
  }

  Future<void> _persistProgressIfNeeded({
    Duration? position,
    Duration? duration,
  }) async {
    if (!_shouldPersistProgress || state.currentItemId == null) {
      return;
    }
    final nextPosition =
        position ??
        (_currentPlaybackPosition > Duration.zero
            ? _currentPlaybackPosition
            : state.position);
    final nextDuration =
        duration ??
        (_currentPlaybackDuration > Duration.zero
            ? _currentPlaybackDuration
            : state.duration);
    if (nextPosition <= Duration.zero || nextDuration <= Duration.zero) {
      return;
    }
    final itemId = state.currentItemId!;
    _markProgressSnapshotSaved(itemId, nextPosition, nextDuration);
    await _progressRepository.saveProgress(
      PlaybackProgress(
        itemId: itemId,
        position: nextPosition,
        duration: nextDuration,
        updatedAt: DateTime.now(),
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

  /// When a real item enters `opening`, no speculative preload may advance to
  /// another playlist/segment. `releasePending` invalidates only the
  /// preloader's continuation; it deliberately leaves an in-flight shared
  /// request alive so the proxy for this item can join it without redownloading
  /// bytes. The predictive scope never includes the current item, so it can
  /// yield immediately as well.
  void _yieldBackgroundPreloadsToOpeningPlayback({
    required String itemId,
    required int playbackGeneration,
  }) {
    final preloadGeneration = ++_preloadGeneration;
    _activePreloadAllowedIds = <String>{itemId};
    _cancelPreloadsNotIn(_activePreloadAllowedIds);
    unawaited(_predictivePreloadManager.releasePending());
    unawaited(() async {
      await _preloadManager.releasePending();
      if (!ref.mounted ||
          _isSessionDisposed ||
          !_isCurrent(playbackGeneration) ||
          preloadGeneration != _preloadGeneration) {
        return;
      }
      _syncPreloadState();
      _logTiming(
        'opening yielded background preloads',
        itemId: itemId,
        details: 'continuations_cancelled=true shared_requests_preserved=true',
      );
    }());
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
    _firstFrameProgressProbeTimer?.cancel();
    _firstFrameVideoRecoveryTimer?.cancel();
    _currentPlaybackHasFirstFrame = false;
    _currentPlaybackPosition = Duration.zero;
    _lastNativePlaybackPosition = Duration.zero;
    _currentPlaybackDuration = Duration.zero;
    _currentPlaybackBufferedPosition = Duration.zero;
    _preloadReadinessStartPosition = null;
    _preloadReadinessReached = false;
    _lastPositionUpdate = null;
    _lastProgressSaveAt = null;
    _lastSavedProgressItemId = null;
    _lastSavedProgressPosition = null;
    _lastSavedProgressDuration = null;
  }

  void _handlePrepareTiming(
    String event, {
    String? itemId,
    String? source,
    String? details,
  }) {
    _logTiming(event, itemId: itemId, source: source, details: details);
    // next 已被静音播放到 warm-up timeout，说明它在真实播放器层并未及时获得首帧。
    // 这可能包含弱网因素，因此后续仍需连续稳定播放才允许恢复，不记成永久结论。
    if (event == 'prepare warm-up timeout') {
      unawaited(
        _enterDecoderPressureMode('next media-session warm-up timed out'),
      );
    }
  }

  /// 只在本会话已观察到真实压力时收紧。高分辨率不是触发条件；它只会增加某些
  /// 设备出现压力的概率，避免让所有 1080p 内容无条件牺牲回滑体验。
  ///
  /// iOS 在两台真机上都确认无法稳定承受 previous/current/next 三个原生 session。
  /// 因此 iOS 永久限制为 current + next；Android 在观察到压力后才收紧，并在连续
  /// 稳定播放后恢复三路资格。
  bool get _shouldConstrainNativeDecoderWindow {
    return _isIosNativeTwoSessionCap || _decoderPressureActive;
  }

  bool get _isIosNativeTwoSessionCap =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<List<String>> _releaseRetainedSessionsForDecoderPressure() async {
    if (_prepareManager is NoopPlayerPlaybackPrepareManager) {
      return const <String>[];
    }
    return _prepareManager.releaseRetained(
      reason: 'native decoder pressure window',
    );
  }

  Future<void> _enterDecoderPressureMode(String reason) async {
    if (!ref.mounted || _isSessionDisposed) {
      return;
    }
    final wasConstrained = _decoderPressureActive;
    _decoderPressureActive = true;
    _decoderPressureStableSince = _isPlaybackStableForDecoderRecovery
        ? DateTime.now()
        : null;
    _decoderPressureReason = reason;
    final released = await _releaseRetainedSessionsForDecoderPressure();
    if (!ref.mounted || _isSessionDisposed) {
      return;
    }
    _logTiming(
      wasConstrained
          ? 'decoder pressure observed again'
          : 'decoder pressure detected',
      itemId: state.currentItemId,
      source: state.currentSource,
      details: _timingDetails([
        'reason=$reason',
        'restoreAfterStablePlaybackMs=${_decoderPressureStablePlayback.inMilliseconds}',
        'releasedRetained=${released.join(',')}',
      ]),
    );
  }

  bool get _isPlaybackStableForDecoderRecovery =>
      state.currentSource != null &&
      state.hasFirstFrame &&
      state.status == PlayerPlaybackStatus.playing &&
      !state.isBuffering &&
      _isPlaybackVisible &&
      !_pauseWhenOpenCompletes;

  void _updateDecoderPressureStability() {
    if (!_decoderPressureActive) {
      return;
    }
    if (!_isPlaybackStableForDecoderRecovery) {
      _decoderPressureStableSince = null;
      return;
    }
    _decoderPressureStableSince ??= DateTime.now();
  }

  void _maybeRestoreDecoderWindowAfterStablePlayback() {
    if (_isIosNativeTwoSessionCap) {
      return;
    }
    _updateDecoderPressureStability();
    final stableSince = _decoderPressureStableSince;
    if (!_decoderPressureActive || stableSince == null) {
      return;
    }
    final stableFor = DateTime.now().difference(stableSince);
    if (stableFor < _decoderPressureStablePlayback) {
      return;
    }
    _decoderPressureActive = false;
    _decoderPressureStableSince = null;
    _decoderPressureReason = null;
    _logTiming(
      'decoder window restored',
      itemId: state.currentItemId,
      source: state.currentSource,
      details: _timingDetails([
        'reason=continuous stable playback',
        'stablePlaybackMs=${stableFor.inMilliseconds}',
      ]),
    );
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
    final itemIds = await _prepareManager.releaseExceptSession(_session);
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
    bool shouldPause = true,
  }) async {
    if (_isSessionDisposed) {
      return;
    }
    _isSessionDisposed = true;
    if (shouldPause) {
      await _session.pause();
    }
    if (disposeDelay > Duration.zero) {
      await Future<void>.delayed(disposeDelay);
    }
    await _session.dispose();
    _logTiming('dispose current session', details: 'reason=dispose session');
  }
}
