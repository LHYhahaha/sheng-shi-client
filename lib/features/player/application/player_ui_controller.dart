import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_content.dart';
import 'player_chrome_auto_immersive_config_provider.dart';

/// 播放器 UI 状态 provider，按 sessionKey 隔离。
///
/// 这里的状态只服务 paywall、集数展示和 UI 意图。真实 play/pause/open/error 必须以
/// PlayerPlaybackController 为准，否则 sheet 打开、For You 切 tab 或单剧返回时会出现
/// UI 以为在播但 media session 已释放的错位。
final playerUiControllerProvider =
    NotifierProvider.family<PlayerUiController, PlayerUiState, String>(
      PlayerUiController.new,
    );

/// 播放器纯 UI 状态。
///
/// 这里只保存 paywall、当前展示集数等 UI 选择，不保存真实播放状态。播放/缓冲/错误
/// 以 PlayerPlaybackState 为准，避免两个状态机互相覆盖。
/// 单剧播放器 chrome 显示模式（非播放真相，仅 UI 层）。
enum PlayerChromeDisplayMode {
  /// 顶栏、侧栏 action、标题/简介、Download/Unlock 等非视频 overlay。
  defaultChrome,

  /// 仅保留视频与底部进度条；locked/unavailable/error/loading 反馈仍显示。
  immersive,
}

class PlayerUiState {
  const PlayerUiState({
    required this.episodeNumber,
    required this.isPlaying,
    required this.paywall,
    required this.chromeDisplayMode,
  });

  const PlayerUiState.initial()
    : episodeNumber = 1,
      isPlaying = false,
      paywall = PlayerPaywallState.hidden,
      chromeDisplayMode = PlayerChromeDisplayMode.defaultChrome;

  /// 当前 UI 展示的集数。
  ///
  /// 用于顶部栏和选集态，不代表播放器已经打开了对应 episode。
  final int episodeNumber;

  /// UI 层的播放意图。
  ///
  /// 这是早期交互态，真实是否播放要看 PlayerPlaybackState.isPlaying。新增播放逻辑
  /// 不应依赖这个字段判断 media session。
  final bool isPlaying;

  /// 当前 paywall 展示状态。
  ///
  /// hidden/unlock/memberUnlock 只影响遮罩和弹层，不代表服务端授权结果。
  final PlayerPaywallState paywall;

  /// 单剧 chrome 默认/沉浸；For You 不使用沉浸切换。
  final PlayerChromeDisplayMode chromeDisplayMode;

  bool get showsPaywall => paywall != PlayerPaywallState.hidden;

  bool get showsChromeOverlays =>
      chromeDisplayMode == PlayerChromeDisplayMode.defaultChrome;

  PlayerUiState copyWith({
    int? episodeNumber,
    bool? isPlaying,
    PlayerPaywallState? paywall,
    PlayerChromeDisplayMode? chromeDisplayMode,
  }) {
    return PlayerUiState(
      episodeNumber: episodeNumber ?? this.episodeNumber,
      isPlaying: isPlaying ?? this.isPlaying,
      paywall: paywall ?? this.paywall,
      chromeDisplayMode: chromeDisplayMode ?? this.chromeDisplayMode,
    );
  }
}

/// 播放器付费遮罩状态。
enum PlayerPaywallState { hidden, unlock, memberUnlock }

/// 播放器 UI 控制器。
///
/// 与 PlayerPlaybackController 分离，是为了让付费弹层、选集和 UI 意图不污染真实
/// 播放器 session 状态。
class PlayerUiController extends Notifier<PlayerUiState> {
  PlayerUiController(this.sessionKey);

  final String sessionKey;

  Timer? _autoImmersiveTimer;
  bool _autoImmersiveSessionEnabled = false;
  bool _playbackIsPlaying = false;
  bool _accessPlayable = false;
  bool _modalBlocking = false;
  bool _isSeeking = false;
  bool _isPageScrolling = false;
  bool _isViewportDragging = false;
  bool _routeVisible = true;

  @override
  PlayerUiState build() {
    ref.onDispose(_cancelAutoImmersiveTimer);
    return const PlayerUiState.initial();
  }

  /// 按 feed 类型启用/关闭自动沉浸（For You 传 `enabled: false`）。
  void configureAutoImmersiveSession({required bool enabled}) {
    _autoImmersiveSessionEnabled = enabled;
    if (!enabled) {
      _cancelAutoImmersiveTimer();
      return;
    }
    _scheduleAutoImmersiveTimer();
  }

  void syncAutoImmersiveBlockers({
    bool? playbackIsPlaying,
    bool? accessPlayable,
    bool? modalBlocking,
    bool? isSeeking,
    bool? isPageScrolling,
    bool? isViewportDragging,
  }) {
    var changed = false;
    if (playbackIsPlaying != null && _playbackIsPlaying != playbackIsPlaying) {
      _playbackIsPlaying = playbackIsPlaying;
      changed = true;
    }
    if (accessPlayable != null && _accessPlayable != accessPlayable) {
      _accessPlayable = accessPlayable;
      changed = true;
    }
    if (modalBlocking != null && _modalBlocking != modalBlocking) {
      _modalBlocking = modalBlocking;
      changed = true;
    }
    if (isSeeking != null && _isSeeking != isSeeking) {
      _isSeeking = isSeeking;
      changed = true;
    }
    if (isPageScrolling != null && _isPageScrolling != isPageScrolling) {
      _isPageScrolling = isPageScrolling;
      changed = true;
    }
    if (isViewportDragging != null &&
        _isViewportDragging != isViewportDragging) {
      _isViewportDragging = isViewportDragging;
      changed = true;
    }
    if (changed) {
      _scheduleAutoImmersiveTimer();
    }
  }

  /// viewport 落稳或切集：回到 default chrome，并按可播状态重启计时。
  void onViewportSettled({
    required bool accessPlayable,
    required bool isItemChange,
  }) {
    _accessPlayable = accessPlayable;
    if (isItemChange) {
      showDefaultChrome();
      _cancelAutoImmersiveTimer();
    }
    _scheduleAutoImmersiveTimer();
  }

  /// 用户操作（点击播放区、拖动 seek 等）：重置自动沉浸计时，不改变当前 chrome。
  void notifyUserInteraction() {
    _scheduleAutoImmersiveTimer();
  }

  /// 沉浸态点击视频区：仅恢复 default chrome，不暂停。
  void onImmersiveVideoTap() {
    showDefaultChrome();
    _scheduleAutoImmersiveTimer();
  }

  void onRouteVisibilityChanged(bool visible) {
    if (_routeVisible == visible) {
      return;
    }
    _routeVisible = visible;
    if (!visible) {
      _cancelAutoImmersiveTimer();
      return;
    }
    _scheduleAutoImmersiveTimer();
  }

  void toggleChromeDisplayMode() {
    final enteringImmersive = state.showsChromeOverlays;
    state = state.copyWith(
      chromeDisplayMode: enteringImmersive
          ? PlayerChromeDisplayMode.immersive
          : PlayerChromeDisplayMode.defaultChrome,
    );
    if (enteringImmersive) {
      _cancelAutoImmersiveTimer();
    } else {
      _scheduleAutoImmersiveTimer();
    }
  }

  void showDefaultChrome() {
    if (!state.showsChromeOverlays) {
      state = state.copyWith(
        chromeDisplayMode: PlayerChromeDisplayMode.defaultChrome,
      );
    }
  }

  void enterImmersiveChrome() {
    if (!state.showsChromeOverlays) {
      return;
    }
    state = state.copyWith(
      chromeDisplayMode: PlayerChromeDisplayMode.immersive,
    );
  }

  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void showMemberPaywall() {
    state = state.copyWith(paywall: PlayerPaywallState.memberUnlock);
    _scheduleAutoImmersiveTimer();
  }

  void showUnlockPaywall() {
    state = state.copyWith(paywall: PlayerPaywallState.unlock);
    _scheduleAutoImmersiveTimer();
  }

  void hidePaywall() {
    state = state.copyWith(paywall: PlayerPaywallState.hidden);
    _scheduleAutoImmersiveTimer();
  }

  void unlockPaywallAndPlay() {
    state = state.copyWith(isPlaying: true, paywall: PlayerPaywallState.hidden);
    _scheduleAutoImmersiveTimer();
  }

  /// session cleanup 时隐藏 paywall 并停止 UI 播放意图。
  void resetForSessionCleanup() {
    _cancelAutoImmersiveTimer();
    _autoImmersiveSessionEnabled = false;
    _playbackIsPlaying = false;
    _accessPlayable = false;
    _modalBlocking = false;
    _isSeeking = false;
    _isPageScrolling = false;
    _isViewportDragging = false;
    _routeVisible = true;
    state = const PlayerUiState.initial();
  }

  void selectEpisode(PlayerEpisode episode) {
    if (episode.isUnavailable) {
      state = state.copyWith(
        episodeNumber: episode.number,
        isPlaying: false,
        paywall: PlayerPaywallState.hidden,
      );
      _scheduleAutoImmersiveTimer();
      return;
    }

    if (episode.isLocked) {
      state = state.copyWith(
        episodeNumber: episode.number,
        isPlaying: false,
        paywall: PlayerPaywallState.unlock,
      );
      _scheduleAutoImmersiveTimer();
      return;
    }

    state = state.copyWith(
      episodeNumber: episode.number,
      isPlaying: true,
      paywall: PlayerPaywallState.hidden,
    );
    _scheduleAutoImmersiveTimer();
  }

  void startSession(String episodeId) {
    final episodeNumber = int.tryParse(episodeId) ?? 1;
    _cancelAutoImmersiveTimer();
    state = PlayerUiState(
      episodeNumber: episodeNumber,
      isPlaying: false,
      paywall: PlayerPaywallState.hidden,
      chromeDisplayMode: PlayerChromeDisplayMode.defaultChrome,
    );
  }

  void _scheduleAutoImmersiveTimer() {
    _cancelAutoImmersiveTimer();
    if (!_canAutoEnterImmersive()) {
      return;
    }
    final config = ref.read(playerChromeAutoImmersiveConfigProvider);
    _autoImmersiveTimer = Timer(config.autoImmersiveDelay, () {
      if (_canAutoEnterImmersive()) {
        enterImmersiveChrome();
      }
    });
  }

  bool _canAutoEnterImmersive() {
    if (!_autoImmersiveSessionEnabled) {
      return false;
    }
    final config = ref.read(playerChromeAutoImmersiveConfigProvider);
    if (!config.enableAutoImmersiveForSingleDrama) {
      return false;
    }
    if (!_playbackIsPlaying) {
      return false;
    }
    if (!_accessPlayable) {
      return false;
    }
    if (_modalBlocking) {
      return false;
    }
    if (_isSeeking) {
      return false;
    }
    if (_isPageScrolling) {
      return false;
    }
    if (_isViewportDragging) {
      return false;
    }
    if (!_routeVisible) {
      return false;
    }
    if (!state.showsChromeOverlays) {
      return false;
    }
    if (state.showsPaywall) {
      return false;
    }
    return true;
  }

  void _cancelAutoImmersiveTimer() {
    _autoImmersiveTimer?.cancel();
    _autoImmersiveTimer = null;
  }
}
