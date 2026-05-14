import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/playback_progress_repository_provider.dart';
import '../data/player_playback_source_repository_provider.dart';
import '../domain/player_feed.dart';
import '../domain/player_playback_progress.dart';
import '../domain/player_playback_source.dart';
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

class PlayerPlaybackSessionKeys {
  const PlayerPlaybackSessionKeys._();

  static const forYouTab = 'for-you-tab';

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
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.isSeeking,
    required this.hasEnded,
    required this.playbackRate,
    this.currentItemId,
    this.currentSource,
    this.seekPreviewPosition,
    this.error,
  });

  const PlayerPlaybackState.initial({VideoController? videoController})
    : this(
        videoController: videoController,
        status: PlayerPlaybackStatus.idle,
        hasFirstFrame: false,
        isBuffering: false,
        preloadedItemIds: const [],
        position: Duration.zero,
        duration: Duration.zero,
        bufferedPosition: Duration.zero,
        isSeeking: false,
        hasEnded: false,
        playbackRate: 1.0,
      );

  final VideoController? videoController;
  final PlayerPlaybackStatus status;
  final bool hasFirstFrame;
  final bool isBuffering;
  final List<String> preloadedItemIds;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isSeeking;
  final bool hasEnded;
  final double playbackRate;
  final String? currentItemId;
  final String? currentSource;
  final Duration? seekPreviewPosition;
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
  bool get isSeekAllowed =>
      currentSource != null &&
      duration > Duration.zero &&
      (status == PlayerPlaybackStatus.playing ||
          status == PlayerPlaybackStatus.paused);
  Duration get displayedPosition => seekPreviewPosition ?? position;
  double get progressValue => _durationRatio(displayedPosition);
  double get bufferedValue => _durationRatio(bufferedPosition);

  PlayerPlaybackState copyWith({
    PlayerPlaybackStatus? status,
    bool? hasFirstFrame,
    bool? isBuffering,
    List<String>? preloadedItemIds,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    bool? isSeeking,
    bool? hasEnded,
    double? playbackRate,
    String? currentItemId,
    String? currentSource,
    Duration? seekPreviewPosition,
    Object? error,
    bool clearError = false,
    bool clearSource = false,
    bool clearSeekPreview = false,
  }) {
    return PlayerPlaybackState(
      videoController: videoController,
      status: status ?? this.status,
      hasFirstFrame: clearSource ? false : hasFirstFrame ?? this.hasFirstFrame,
      isBuffering: clearSource ? false : isBuffering ?? this.isBuffering,
      preloadedItemIds: preloadedItemIds ?? this.preloadedItemIds,
      position: clearSource ? Duration.zero : position ?? this.position,
      duration: clearSource ? Duration.zero : duration ?? this.duration,
      bufferedPosition: clearSource
          ? Duration.zero
          : bufferedPosition ?? this.bufferedPosition,
      isSeeking: clearSource ? false : isSeeking ?? this.isSeeking,
      hasEnded: clearSource ? false : hasEnded ?? this.hasEnded,
      playbackRate: playbackRate ?? this.playbackRate,
      currentItemId: clearSource ? null : currentItemId ?? this.currentItemId,
      currentSource: clearSource ? null : currentSource ?? this.currentSource,
      seekPreviewPosition: clearSource || clearSeekPreview
          ? null
          : seekPreviewPosition ?? this.seekPreviewPosition,
      error: clearError ? null : error ?? this.error,
    );
  }

  double _durationRatio(Duration value) {
    if (duration <= Duration.zero) {
      return 0;
    }
    return (value.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class PlayerPlaybackController extends Notifier<PlayerPlaybackState> {
  PlayerPlaybackController(this.sessionKey);

  static const _maxPreloadedSources = 2;

  final String sessionKey;
  late final PlayerPlaybackSession _session;
  late final PlayerPlaybackCacheManager _cacheManager;
  late final PlaybackProgressRepository _progressRepository;
  final _preloadedItemIds = <String>{};
  int _generation = 0;
  int _preloadGeneration = 0;
  bool _pauseWhenOpenCompletes = false;
  bool _isSessionDisposed = false;
  bool _wasPlayingBeforeSeek = false;
  bool _ignoreNextCompleted = false;
  Duration? _lastPositionUpdate;

  @override
  PlayerPlaybackState build() {
    _session = ref.read(playerPlaybackSessionFactoryProvider).call();
    _cacheManager = ref.read(playerPlaybackCacheManagerProvider);
    _progressRepository = ref.read(playbackProgressRepositoryProvider);
    final subscriptions = <StreamSubscription<dynamic>>[
      _session.bufferingStream.listen(_handleBuffering),
      _session.playingStream.listen(_handlePlaying),
      _session.completedStream.listen(_handleCompleted),
      _session.positionStream.listen(_handlePosition),
      _session.durationStream.listen(_handleDuration),
      _session.bufferedPositionStream.listen(_handleBufferedPosition),
      _session.rateStream.listen(_handleRate),
      _session.widthStream.listen(_handleWidth),
      _session.errorStream.listen(_handleError),
    ];
    ref.onDispose(() {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      unawaited(_disposePreloads());
      unawaited(_disposeSessionOnly());
    });
    return PlayerPlaybackState.initial(
      videoController: _session.videoController,
    );
  }

  Future<void> playItem(PlayerFeedItem? item) async {
    if (_isSessionDisposed) {
      return;
    }

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

    final sourceHint = item.episode.videoSource;
    if (item.episode.isUnavailable || sourceHint == null) {
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
        state.currentItemId == item.id &&
        state.currentSource != null &&
        state.status != PlayerPlaybackStatus.error;
    if (isSameSource && !state.hasEnded) {
      return;
    }

    final generation = ++_generation;
    _pauseWhenOpenCompletes = false;
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
    );

    try {
      final playbackSource = await ref
          .read(playerPlaybackSourceRepositoryProvider)
          .resolve(item);
      if (!ref.mounted) {
        return;
      }
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(currentSource: playbackSource.playableSource);
      await _session.open(playbackSource.playableSource, play: true);
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
    if (_isSessionDisposed) {
      return;
    }

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
          item.id == state.currentItemId ||
          source == state.currentSource) {
        continue;
      }
      candidates.add(item);
    }

    final preloadGeneration = _preloadGeneration;
    final allowedIds = candidates
        .take(_maxPreloadedSources)
        .map((item) => item.id)
        .toSet();

    _preloadedItemIds.removeWhere((id) => !allowedIds.contains(id));

    _setPreloadedItemIds(_preloadedItemIds.toList(growable: false));

    for (final item in candidates.take(_maxPreloadedSources)) {
      if (_preloadedItemIds.contains(item.id)) {
        continue;
      }
      _preloadedItemIds.add(item.id);
      _setPreloadedItemIds(_preloadedItemIds.toList(growable: false));
      try {
        await ref.read(playerPlaybackSourceRepositoryProvider).preload(item);
        if (!ref.mounted ||
            _isSessionDisposed ||
            preloadGeneration != _preloadGeneration) {
          _preloadedItemIds.remove(item.id);
          if (ref.mounted && !_isSessionDisposed) {
            _setPreloadedItemIds(_preloadedItemIds.toList(growable: false));
          }
          return;
        }
      } catch (_) {
        _preloadedItemIds.remove(item.id);
        if (ref.mounted &&
            !_isSessionDisposed &&
            preloadGeneration == _preloadGeneration) {
          _setPreloadedItemIds(_preloadedItemIds.toList(growable: false));
        }
      }
    }
  }

  Future<void> togglePlay() async {
    if (_isSessionDisposed) {
      return;
    }

    if (state.status == PlayerPlaybackStatus.playing) {
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

  Future<void> pauseForVisibility() async {
    if (_isSessionDisposed) {
      return;
    }
    _pauseWhenOpenCompletes = true;
    ++_generation;
    await _session.pause();
    await _disposePreloads();
    if (!ref.mounted) {
      return;
    }
    if (state.currentSource == null ||
        state.status == PlayerPlaybackStatus.blocked ||
        state.status == PlayerPlaybackStatus.unavailable ||
        state.status == PlayerPlaybackStatus.error ||
        state.status == PlayerPlaybackStatus.idle) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.paused,
      isBuffering: false,
    );
  }

  Future<void> disposeSession() async {
    _pauseWhenOpenCompletes = true;
    ++_generation;
    await _disposePreloads();
    await _disposeSessionOnly();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      status: PlayerPlaybackStatus.idle,
      clearSource: true,
      clearError: true,
      preloadedItemIds: const [],
    );
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

  void _handlePlaying(bool isPlaying) {
    if (_pauseWhenOpenCompletes && isPlaying) {
      return;
    }
    if (state.currentSource == null ||
        state.status == PlayerPlaybackStatus.error ||
        state.status == PlayerPlaybackStatus.blocked ||
        state.status == PlayerPlaybackStatus.unavailable ||
        state.status == PlayerPlaybackStatus.opening) {
      return;
    }
    state = state.copyWith(
      status: isPlaying
          ? PlayerPlaybackStatus.playing
          : PlayerPlaybackStatus.paused,
      hasEnded: isPlaying ? false : state.hasEnded,
    );
  }

  void _handleCompleted(bool completed) {
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
    state = state.copyWith(position: clamped);
    _saveProgressIfNeeded(position: clamped);
  }

  void _handleDuration(Duration duration) {
    if (state.currentSource == null) {
      return;
    }
    final normalized = duration < Duration.zero ? Duration.zero : duration;
    state = state.copyWith(duration: normalized);
    _saveProgressIfNeeded(duration: normalized);
  }

  void _handleBufferedPosition(Duration position) {
    if (state.currentSource == null) {
      return;
    }
    state = state.copyWith(bufferedPosition: _clampToDuration(position));
  }

  void _handleRate(double rate) {
    if (rate <= 0) {
      return;
    }
    state = state.copyWith(playbackRate: rate);
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

  void _setPreloadedItemIds(List<String> ids) {
    state = state.copyWith(preloadedItemIds: List<String>.unmodifiable(ids));
  }

  Future<void> _disposePreloads() async {
    _preloadGeneration += 1;
    _preloadedItemIds.clear();
    await _cacheManager.releasePending();
  }

  Future<void> _disposeSessionOnly() async {
    if (_isSessionDisposed) {
      return;
    }
    _isSessionDisposed = true;
    await _session.pause();
    await _session.dispose();
  }
}
