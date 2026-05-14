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
    required this.isBuffering,
    required this.preloadedItemIds,
    this.currentItemId,
    this.currentSource,
    this.error,
  });

  const PlayerPlaybackState.initial({VideoController? videoController})
    : this(
        videoController: videoController,
        status: PlayerPlaybackStatus.idle,
        hasFirstFrame: false,
        isBuffering: false,
        preloadedItemIds: const [],
      );

  final VideoController? videoController;
  final PlayerPlaybackStatus status;
  final bool hasFirstFrame;
  final bool isBuffering;
  final List<String> preloadedItemIds;
  final String? currentItemId;
  final String? currentSource;
  final Object? error;

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

  PlayerPlaybackState copyWith({
    PlayerPlaybackStatus? status,
    bool? hasFirstFrame,
    bool? isBuffering,
    List<String>? preloadedItemIds,
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
      isBuffering: clearSource ? false : isBuffering ?? this.isBuffering,
      preloadedItemIds: preloadedItemIds ?? this.preloadedItemIds,
      currentItemId: clearSource ? null : currentItemId ?? this.currentItemId,
      currentSource: clearSource ? null : currentSource ?? this.currentSource,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PlayerPlaybackController extends Notifier<PlayerPlaybackState> {
  PlayerPlaybackController(this.sessionKey);

  static const _maxPreloadedSources = 2;

  final String sessionKey;
  late final PlayerPlaybackSession _session;
  final _preloadedSessions = <String, PlayerPlaybackSession>{};
  int _generation = 0;

  @override
  PlayerPlaybackState build() {
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    final subscriptions = <StreamSubscription<dynamic>>[
      _session.bufferingStream.listen(_handleBuffering),
      _session.widthStream.listen(_handleWidth),
      _session.errorStream.listen(_handleError),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(_disposePreloads());
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
      isBuffering: true,
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
        isBuffering: false,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerPlaybackStatus.error,
        hasFirstFrame: false,
        isBuffering: false,
        error: error,
      );
    }
  }

  Future<void> preloadAround(
    List<PlayerFeedItem> items,
    int currentIndex,
  ) async {
    if (items.isEmpty) {
      await _disposePreloads();
      _setPreloadedItemIds(const []);
      return;
    }

    final candidates = <PlayerFeedItem>[];
    for (final index in [currentIndex + 1, currentIndex - 1]) {
      if (index < 0 || index >= items.length) {
        continue;
      }
      final item = items[index];
      final source = item.episode.videoSource;
      if (item.episode.isLocked ||
          item.episode.isUnavailable ||
          source == null ||
          source == state.currentSource) {
        continue;
      }
      candidates.add(item);
    }

    final allowedIds = candidates
        .take(_maxPreloadedSources)
        .map((item) => item.id)
        .toSet();

    for (final entry in [..._preloadedSessions.entries]) {
      if (!allowedIds.contains(entry.key)) {
        _preloadedSessions.remove(entry.key);
        unawaited(entry.value.dispose());
      }
    }

    _setPreloadedItemIds(_preloadedSessions.keys.toList(growable: false));

    for (final item in candidates.take(_maxPreloadedSources)) {
      if (_preloadedSessions.containsKey(item.id)) {
        continue;
      }
      final source = item.episode.videoSource;
      if (source == null) {
        continue;
      }
      final session = ref.read(playerPlaybackSessionFactoryProvider).call();
      _preloadedSessions[item.id] = session;
      _setPreloadedItemIds(_preloadedSessions.keys.toList(growable: false));
      try {
        await session.open(source, play: false);
      } catch (_) {
        final failed = _preloadedSessions.remove(item.id);
        unawaited(failed?.dispose());
        _setPreloadedItemIds(_preloadedSessions.keys.toList(growable: false));
      }
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

  void _handleBuffering(bool isBuffering) {
    if (state.currentSource == null ||
        state.status == PlayerPlaybackStatus.error ||
        state.status == PlayerPlaybackStatus.blocked ||
        state.status == PlayerPlaybackStatus.unavailable) {
      return;
    }
    state = state.copyWith(isBuffering: isBuffering);
  }

  void _handleWidth(int? width) {
    if (width == null || width <= 0 || state.currentSource == null) {
      return;
    }
    state = state.copyWith(
      status: state.status == PlayerPlaybackStatus.opening
          ? PlayerPlaybackStatus.playing
          : state.status,
      hasFirstFrame: true,
      isBuffering: false,
    );
  }

  void _handleError(String error) {
    if (state.currentSource == null) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.error,
      hasFirstFrame: false,
      isBuffering: false,
      error: error,
    );
  }

  Future<bool> _pauseIfCurrent(int generation) async {
    await _session.pause();
    if (!_isCurrent(generation)) {
      return false;
    }
    return true;
  }

  bool _isCurrent(int generation) => generation == _generation;

  void _setPreloadedItemIds(List<String> ids) {
    state = state.copyWith(preloadedItemIds: List<String>.unmodifiable(ids));
  }

  Future<void> _disposePreloads() async {
    final sessions = _preloadedSessions.values.toList(growable: false);
    _preloadedSessions.clear();
    await Future.wait<void>(sessions.map((session) => session.dispose()));
  }
}
