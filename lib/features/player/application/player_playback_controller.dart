import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/playback_progress_repository_provider.dart';
import '../data/player_playback_source_repository_provider.dart';
import '../domain/player_feed.dart';
import '../domain/player_playback_progress.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import 'player_playback_prepare_manager.dart';
import 'player_playback_timing_trace.dart';
import 'player_session_controller.dart';

final playerPlaybackSessionFactoryProvider =
    Provider<PlayerPlaybackSession Function()>((ref) {
      return MediaKitPlayerSession.new;
    });

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
      );

  final VideoController? videoController;
  final PlayerPlaybackStatus status;
  final bool hasFirstFrame;
  final bool isBuffering;
  final List<String> preloadedItemIds;
  final List<PlaybackPreloadState> preloadStates;
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
      currentItemId: clearSource ? null : currentItemId ?? this.currentItemId,
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

class PlayerPlaybackController extends Notifier<PlayerPlaybackState> {
  PlayerPlaybackController(this.sessionKey);

  static const _maxPreloadedSources = 2;

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
  bool _isSessionDisposed = false;
  bool _wasPlayingBeforeSeek = false;
  bool _ignoreNextCompleted = false;
  Duration? _lastPositionUpdate;
  late final _timingTrace = PlayerPlaybackTimingTrace(sessionKey: sessionKey);
  final _playingBeforeFirstFrameLoggedItemIds = <String>{};
  final _positionBeforeFirstFrameLoggedItemIds = <String>{};
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
      unawaited(_cancelSessionStreams());
      unawaited(_disposePreloads(syncState: false));
      unawaited(_releaseSessionWindowFor('provider dispose'));
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
      _currentPlaybackItemId = null;
      _currentPlaybackSource = null;
      _clearCurrentPlaybackSnapshot();
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
      _currentPlaybackItemId = null;
      _currentPlaybackSource = null;
      _clearCurrentPlaybackSnapshot();
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
      _currentPlaybackItemId = null;
      _currentPlaybackSource = null;
      _clearCurrentPlaybackSnapshot();
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
    _logTiming(
      'trace generation assigned',
      itemId: item.id,
      source: sourceHint,
      details: 'generation=$generation',
    );
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

    var didResolveSource = false;
    try {
      final windowItemsBeforeTake = _windowItemsText();
      final prepared = _prepareManager.takeIfMatches(item.id);
      _logTiming(
        'take window session',
        itemId: item.id,
        source: prepared?.source.playableSource ?? sourceHint,
        details: _timingDetails([
          'requestedItemId=${item.id}',
          'hit=${prepared != null}',
          if (prepared != null) 'kind=${prepared.kind.name}',
          if (prepared != null) 'firstFrameReady=${prepared.hasFirstFrame}',
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
            'firstFrameReady=${prepared.hasFirstFrame}',
          ]),
        );
        await _replaceCurrentSession(prepared);
        if (!ref.mounted || !_isCurrent(generation)) {
          await _session.pause();
          return;
        }
        state = state.copyWith(
          videoController: _session.videoController,
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

    final candidates = <PlayerFeedItem>[];
    final skipped = <String>[];
    for (final index in [currentIndex + 1, currentIndex - 1]) {
      if (index < 0 || index >= items.length) {
        skipped.add('index:$index:out_of_range');
        continue;
      }
      final item = items[index];
      final source = item.episode.videoSource;
      final skipReasons = <String>[
        if (item.episode.isLocked) 'locked',
        if (item.episode.isUnavailable) 'unavailable',
        if (source == null) 'null_source',
        if (item.id == state.currentItemId) 'current_item',
      ];
      if (skipReasons.isNotEmpty) {
        skipped.add('${item.id}:${skipReasons.join('+')}');
        continue;
      }
      candidates.add(item);
    }

    final allowedIds = candidates
        .take(_maxPreloadedSources)
        .map((item) => item.id)
        .toSet();
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
      ]),
    );
    final preloadGeneration = setEquals(_activePreloadAllowedIds, allowedIds)
        ? _preloadGeneration
        : ++_preloadGeneration;
    _activePreloadAllowedIds = allowedIds;

    _preloadedItemIds.removeWhere((id) => !allowedIds.contains(id));
    _cancelPreloadsNotIn(allowedIds);
    unawaited(
      _retainSessionWindowOnly(
        allowedIds,
        reason: 'stale generation/window trim',
      ),
    );

    _syncPreloadState();

    if (state.currentItemId != null && state.currentSource != null) {
      final nextItem = candidates.isEmpty ? null : candidates.first;
      if (nextItem != null) {
        unawaited(_prepareNextItem(nextItem, preloadGeneration));
      }
    }

    for (final item in candidates.take(_maxPreloadedSources)) {
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

  Future<void> pauseForVisibility({bool syncState = true}) async {
    if (_isSessionDisposed) {
      return;
    }
    _pauseWhenOpenCompletes = true;
    ++_generation;
    await _session.pause();
    await _releaseSessionWindowFor('hidden');
    await _disposePreloads(syncState: syncState);
    if (!syncState || !ref.mounted) {
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

  Future<void> disposeSession({bool syncState = true}) async {
    _pauseWhenOpenCompletes = true;
    ++_generation;
    await _releaseSessionWindowFor('dispose');
    await _disposePreloads(syncState: syncState);
    _preloadStates.clear();
    _preloadedItemIds.clear();
    await _disposeSessionOnly();
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
    state = state.copyWith(videoController: _session.videoController);
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
      if (allowedIds.contains(entry.key) &&
          entry.value.status != PlaybackPreloadStatus.pending) {
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
    _preloadGeneration += 1;
    _activePreloadAllowedIds = <String>{};
    _cancelPendingPreloads(syncState: syncState);
    await _preloadManager.releasePending();
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
    final itemIds = _prepareManager.windowItemIds;
    await _prepareManager.release();
    for (final itemId in itemIds) {
      _logTiming(
        'dispose window session',
        itemId: itemId,
        details: 'reason=$reason',
      );
    }
    _logTiming(
      'session window release',
      details: _timingDetails([
        'reason=$reason',
        'released=${itemIds.join(',')}',
      ]),
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

  Future<void> _disposeSessionOnly() async {
    if (_isSessionDisposed) {
      return;
    }
    _isSessionDisposed = true;
    await _session.pause();
    await _session.dispose();
    _logTiming('dispose current session', details: 'reason=dispose session');
  }
}
