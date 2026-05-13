import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_content.dart';

final playerUiControllerProvider =
    NotifierProvider.family<PlayerUiController, PlayerUiState, String>(
      PlayerUiController.new,
    );

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

  final int episodeNumber;
  final bool isPlaying;
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

enum PlayerPaywallState { hidden, unlock, memberUnlock }

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
