import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_content.dart';

final playerUiControllerProvider =
    NotifierProvider.family<PlayerUiController, PlayerUiState, String>(
      PlayerUiController.new,
    );

/// 播放器纯 UI 状态。
///
/// 这里只保存 paywall、当前展示集数等 UI 选择，不保存真实播放状态。播放/缓冲/错误
/// 以 PlayerPlaybackState 为准，避免两个状态机互相覆盖。
class PlayerUiState {
  const PlayerUiState({
    required this.episodeNumber,
    required this.isPlaying,
    required this.paywall,
  });

  const PlayerUiState.initial()
    : episodeNumber = 1,
      isPlaying = false,
      paywall = PlayerPaywallState.hidden;

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

  bool get showsPaywall => paywall != PlayerPaywallState.hidden;

  PlayerUiState copyWith({
    int? episodeNumber,
    bool? isPlaying,
    PlayerPaywallState? paywall,
  }) {
    return PlayerUiState(
      episodeNumber: episodeNumber ?? this.episodeNumber,
      isPlaying: isPlaying ?? this.isPlaying,
      paywall: paywall ?? this.paywall,
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

  @override
  PlayerUiState build() => const PlayerUiState.initial();

  void startSession(String episodeId) {
    final episodeNumber = int.tryParse(episodeId) ?? 1;
    state = PlayerUiState(
      episodeNumber: episodeNumber,
      isPlaying: false,
      paywall: PlayerPaywallState.hidden,
    );
  }

  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void showMemberPaywall() {
    state = state.copyWith(paywall: PlayerPaywallState.memberUnlock);
  }

  void hidePaywall() {
    state = state.copyWith(paywall: PlayerPaywallState.hidden);
  }

  void unlockPaywallAndPlay() {
    state = state.copyWith(isPlaying: true, paywall: PlayerPaywallState.hidden);
  }

  void selectEpisode(PlayerEpisode episode) {
    if (episode.isUnavailable) {
      state = state.copyWith(
        episodeNumber: episode.number,
        isPlaying: false,
        paywall: PlayerPaywallState.hidden,
      );
      return;
    }

    if (episode.isLocked) {
      state = state.copyWith(
        episodeNumber: episode.number,
        isPlaying: false,
        paywall: PlayerPaywallState.unlock,
      );
      return;
    }

    state = state.copyWith(
      episodeNumber: episode.number,
      isPlaying: true,
      paywall: PlayerPaywallState.hidden,
    );
  }
}
