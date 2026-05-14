import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/player_feed.dart';
import 'player_session_controller.dart';

final playerPlaybackSessionFactoryProvider =
    Provider<PlayerPlaybackSession Function()>((ref) {
      return MediaKitPlayerSession.new;
    });

final playerPlaybackControllerProvider =
    NotifierProvider.family<
      PlayerPlaybackController,
      PlayerPlaybackState,
      String
    >(PlayerPlaybackController.new);

enum PlayerPlaybackStatus {
  idle,
  opening,
  playing,
  paused,
  blocked,
  unavailable,
  error,
}

class PlayerPlaybackState {
  const PlayerPlaybackState({
    required this.videoController,
    required this.status,
    this.currentItemId,
    this.currentSource,
    this.error,
  });

  const PlayerPlaybackState.initial({VideoController? videoController})
    : this(videoController: videoController, status: PlayerPlaybackStatus.idle);

  final VideoController? videoController;
  final PlayerPlaybackStatus status;
  final String? currentItemId;
  final String? currentSource;
  final Object? error;

  bool get isPlaying => status == PlayerPlaybackStatus.playing;

  PlayerPlaybackState copyWith({
    PlayerPlaybackStatus? status,
    String? currentItemId,
    String? currentSource,
    Object? error,
    bool clearError = false,
    bool clearSource = false,
  }) {
    return PlayerPlaybackState(
      videoController: videoController,
      status: status ?? this.status,
      currentItemId: clearSource ? null : currentItemId ?? this.currentItemId,
      currentSource: clearSource ? null : currentSource ?? this.currentSource,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PlayerPlaybackController extends Notifier<PlayerPlaybackState> {
  PlayerPlaybackController(this.sessionKey);

  final String sessionKey;
  late final PlayerPlaybackSession _session;
  int _generation = 0;

  @override
  PlayerPlaybackState build() {
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    ref.onDispose(() {
      unawaited(_session.dispose());
    });
    return PlayerPlaybackState.initial(
      videoController: _session.videoController,
    );
  }

  Future<void> playItem(PlayerFeedItem? item) async {
    final generation = ++_generation;

    if (item == null) {
      if (!await _pauseIfCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.idle,
        clearSource: true,
        clearError: true,
      );
      return;
    }

    if (item.episode.isLocked) {
      if (!await _pauseIfCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.blocked,
        currentItemId: item.id,
        clearSource: true,
        clearError: true,
      );
      return;
    }

    final source = item.episode.videoSource;
    if (item.episode.isUnavailable || source == null) {
      if (!await _pauseIfCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.unavailable,
        currentItemId: item.id,
        clearSource: true,
        clearError: true,
      );
      return;
    }

    if (state.currentItemId == item.id &&
        state.currentSource == source &&
        state.status == PlayerPlaybackStatus.playing) {
      return;
    }

    state = state.copyWith(
      status: PlayerPlaybackStatus.opening,
      currentItemId: item.id,
      currentSource: source,
      clearError: true,
    );

    try {
      await _session.open(source, play: true);
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(status: PlayerPlaybackStatus.playing);
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(status: PlayerPlaybackStatus.error, error: error);
    }
  }

  Future<void> togglePlay() async {
    if (state.status == PlayerPlaybackStatus.playing) {
      await _session.pause();
      state = state.copyWith(status: PlayerPlaybackStatus.paused);
      return;
    }

    if (state.currentSource == null) {
      return;
    }

    await _session.play();
    state = state.copyWith(status: PlayerPlaybackStatus.playing);
  }

  Future<void> pause() async {
    await _session.pause();
    state = state.copyWith(status: PlayerPlaybackStatus.paused);
  }

  Future<bool> _pauseIfCurrent(int generation) async {
    await _session.pause();
    if (!_isCurrent(generation)) {
      return false;
    }
    return true;
  }

  bool _isCurrent(int generation) => generation == _generation;
}
