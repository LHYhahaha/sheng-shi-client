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
    required this.hasFirstFrame,
    this.currentItemId,
    this.currentSource,
    this.error,
  });

  const PlayerPlaybackState.initial({VideoController? videoController})
    : this(
        videoController: videoController,
        status: PlayerPlaybackStatus.idle,
        hasFirstFrame: false,
      );

  final VideoController? videoController;
  final PlayerPlaybackStatus status;
  final bool hasFirstFrame;
  final String? currentItemId;
  final String? currentSource;
  final Object? error;

  bool get isPlaying => status == PlayerPlaybackStatus.playing;
  bool get isOpening => status == PlayerPlaybackStatus.opening;

  PlayerPlaybackState copyWith({
    PlayerPlaybackStatus? status,
    bool? hasFirstFrame,
    String? currentItemId,
    String? currentSource,
    Object? error,
    bool clearError = false,
    bool clearSource = false,
  }) {
    return PlayerPlaybackState(
      videoController: videoController,
      status: status ?? this.status,
      hasFirstFrame: clearSource ? false : hasFirstFrame ?? this.hasFirstFrame,
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
    if (item == null) {
      final generation = ++_generation;
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
      final generation = ++_generation;
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
      final generation = ++_generation;
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

    final isSameSource =
        state.currentItemId == item.id && state.currentSource == source;
    if (isSameSource && state.status != PlayerPlaybackStatus.error) {
      return;
    }

    final generation = ++_generation;
    state = state.copyWith(
      status: PlayerPlaybackStatus.opening,
      hasFirstFrame: false,
      currentItemId: item.id,
      currentSource: source,
      clearError: true,
    );

    try {
      await _session.open(source, play: true);
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.playing,
        hasFirstFrame: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.error,
        hasFirstFrame: false,
        error: error,
      );
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
