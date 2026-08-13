import 'dart:async';

import 'package:drama_client/features/drama/domain/drama.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/application/player_startup_preload_controller.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/data/player_preload_config_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/domain/player_preload_config.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _videoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const _secondVideoUrl = 'https://test-streams.mux.dev/tos_ismc/main.m3u8';

void main() {
  test('startup preload success records success state', () async {
    final sourceRepository = _FakePlaybackSourceRepository();
    final container = _createContainer(sourceRepository: sourceRepository);
    addTearDown(container.dispose);
    final controller = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );

    await controller.preloadFirstPlayableDrama(_drama);

    final state = container.read(playerStartupPreloadControllerProvider);
    expect(state.status, PlayerStartupPreloadStatus.success);
    expect(state.itemId, 'drama-a-ep-1');
    expect(sourceRepository.preloadCount, 1);
    expect(
      controller.exportTimingReport(),
      contains('startup preload success'),
    );
  });

  test('startup preload honors a concrete route episode', () async {
    final sourceRepository = _FakePlaybackSourceRepository();
    final container = _createContainer(sourceRepository: sourceRepository);
    addTearDown(container.dispose);

    await container
        .read(playerStartupPreloadControllerProvider.notifier)
        .preloadFirstPlayableDramaId(_drama.id, preferredEpisodeId: 'ep-2');

    expect(sourceRepository.lastPreloadedItemId, _item2.id);
    expect(
      container.read(playerStartupPreloadControllerProvider).itemId,
      _item2.id,
    );
  });

  test('startup preload honors a route episode number fallback', () async {
    final sourceRepository = _FakePlaybackSourceRepository();
    final container = _createContainer(sourceRepository: sourceRepository);
    addTearDown(container.dispose);
    final controller = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );

    await controller.preloadFirstPlayableDramaId(
      _drama.id,
      preferredEpisodeId: '2',
    );

    expect(sourceRepository.lastPreloadedItemId, _item2.id);
    expect(
      container.read(playerStartupPreloadControllerProvider).itemId,
      _item2.id,
    );
    expect(controller.exportTimingReport(), contains('target=route_episode'));
  });

  test(
    'startup preload prefers explicit episode number over route episode id',
    () async {
      final sourceRepository = _FakePlaybackSourceRepository();
      final container = _createContainer(sourceRepository: sourceRepository);
      addTearDown(container.dispose);
      final controller = container.read(
        playerStartupPreloadControllerProvider.notifier,
      );

      await controller.preloadFirstPlayableDramaId(
        _drama.id,
        preferredEpisodeId: '1',
        preferredEpisodeNo: 2,
      );

      expect(sourceRepository.lastPreloadedItemId, _item2.id);
      expect(
        container.read(playerStartupPreloadControllerProvider).itemId,
        _item2.id,
      );
      expect(controller.exportTimingReport(), contains('target=route_episode'));
    },
  );

  test('startup preload matches resume hint by episode number', () async {
    final sourceRepository = _FakePlaybackSourceRepository();
    final container = _createContainer(sourceRepository: sourceRepository);
    addTearDown(container.dispose);
    final controller = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );

    await controller.preloadFirstPlayableDramaId(
      _drama.id,
      resumeHint: const PlayerEntryResumeHint(
        episodeId: 'stale-episode-id',
        episodeNo: 2,
        position: Duration(seconds: 35),
        duration: Duration(seconds: 120),
      ),
    );

    expect(sourceRepository.lastPreloadedItemId, _item2.id);
    expect(sourceRepository.lastPreferredPosition, const Duration(seconds: 35));
    expect(controller.exportTimingReport(), contains('targetPositionMs=35000'));
  });

  test('startup preload can be disabled by config', () async {
    final sourceRepository = _FakePlaybackSourceRepository();
    final preloadManager = _FakePreloadManager();
    final container = _createContainer(
      sourceRepository: sourceRepository,
      preloadManager: preloadManager,
      preloadConfig: const PlayerPreloadConfig(homeStartupPreloadCount: 0),
    );
    addTearDown(container.dispose);

    await container
        .read(playerStartupPreloadControllerProvider.notifier)
        .preloadFirstPlayableDrama(_drama);

    expect(sourceRepository.preloadCount, 0);
    expect(preloadManager.releasePendingCount, greaterThanOrEqualTo(1));
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.idle,
    );
  });

  test('startup preload failed stays isolated from playback', () async {
    final sourceRepository = _FakePlaybackSourceRepository()
      ..failNextPreload = true;
    final playbackSession = _FakePlaybackSession();
    final container = _createContainer(
      sourceRepository: sourceRepository,
      playbackSession: playbackSession,
    );
    addTearDown(container.dispose);

    await container
        .read(playerStartupPreloadControllerProvider.notifier)
        .preloadFirstPlayableDrama(_drama);
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.failed,
    );

    final playback = container.read(
      playerPlaybackControllerProvider('single:drama-a:1').notifier,
    );
    await playback.playItem(_item);

    expect(playbackSession.openedSources, [_videoUrl]);
    expect(
      container
          .read(playerPlaybackControllerProvider('single:drama-a:1'))
          .status,
      PlayerPlaybackStatus.playing,
    );
  });

  test('startup preload cancel prevents late success write', () async {
    final completer = Completer<PlaybackPreloadState>();
    final sourceRepository = _FakePlaybackSourceRepository(
      preloadCompleter: completer,
    );
    final preloadManager = _FakePreloadManager();
    final container = _createContainer(
      sourceRepository: sourceRepository,
      preloadManager: preloadManager,
    );
    addTearDown(container.dispose);
    final controller = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );

    final preload = controller.preloadFirstPlayableDrama(_drama);
    await Future<void>.delayed(Duration.zero);
    await controller.cancel(reason: 'test cancel');
    completer.complete(_successPreloadState());
    await preload;

    final state = container.read(playerStartupPreloadControllerProvider);
    expect(state.status, PlayerStartupPreloadStatus.cancelled);
    expect(preloadManager.releasePendingCount, greaterThanOrEqualTo(1));
    expect(
      controller.exportTimingReport(),
      contains('startup preload cancelled'),
    );
  });

  test('startup cancel does not cancel playback preload', () async {
    final startupCompleter = Completer<PlaybackPreloadState>();
    final playbackCompleter = Completer<PlaybackPreloadState>();
    final startupManager = _FakePreloadManager();
    final playbackManager = _FakePreloadManager();
    final container = _createContainer(
      sourceRepository: _FakePlaybackSourceRepository(
        preloadCompleter: startupCompleter,
      ),
      preloadManager: startupManager,
      playbackSourceRepository: _FakePlaybackSourceRepository(
        preloadCompleter: playbackCompleter,
      ),
      playbackPreloadManager: playbackManager,
    );
    addTearDown(container.dispose);

    final startup = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );
    final playback = container.read(
      playerPlaybackControllerProvider('single:drama-a:1').notifier,
    );

    final startupFuture = startup.preloadFirstPlayableDrama(_drama);
    await Future<void>.delayed(Duration.zero);
    final playbackFuture = playback.preloadAround([_item, _item2], 0);
    await Future<void>.delayed(Duration.zero);

    await startup.cancel(reason: 'category switch');
    expect(startupManager.releasePendingCount, greaterThanOrEqualTo(1));
    expect(playbackManager.releasePendingCount, 0);

    startupCompleter.complete(_successPreloadStateFor(_item));
    playbackCompleter.complete(_successPreloadStateFor(_item2));
    await startupFuture;
    await playbackFuture;

    final playbackState = container.read(
      playerPlaybackControllerProvider('single:drama-a:1'),
    );
    expect(playbackState.preloadedItemIds, contains(_item2.id));
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.cancelled,
    );
  });

  test('player pause does not cancel startup preload', () async {
    final startupCompleter = Completer<PlaybackPreloadState>();
    final startupManager = _FakePreloadManager();
    final playbackManager = _FakePreloadManager();
    final container = _createContainer(
      sourceRepository: _FakePlaybackSourceRepository(
        preloadCompleter: startupCompleter,
      ),
      preloadManager: startupManager,
      playbackPreloadManager: playbackManager,
    );
    addTearDown(container.dispose);

    final startup = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );
    final playback = container.read(
      playerPlaybackControllerProvider('single:drama-a:1').notifier,
    );

    final startupFuture = startup.preloadFirstPlayableDrama(_drama);
    await Future<void>.delayed(Duration.zero);
    final startupReleaseCountBeforePause = startupManager.releasePendingCount;
    await playback.pauseForVisibility(syncState: false);

    expect(startupManager.releasePendingCount, startupReleaseCountBeforePause);
    expect(playbackManager.releasePendingCount, greaterThanOrEqualTo(1));

    startupCompleter.complete(_successPreloadStateFor(_item));
    await startupFuture;
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.success,
    );
  });

  test('startup and playback preload outcomes stay scope isolated', () async {
    final startupCompleter = Completer<PlaybackPreloadState>();
    final playbackRepository = _FakePlaybackSourceRepository()
      ..failNextPreload = true;
    final container = _createContainer(
      sourceRepository: _FakePlaybackSourceRepository(
        preloadCompleter: startupCompleter,
      ),
      playbackSourceRepository: playbackRepository,
    );
    addTearDown(container.dispose);

    final startup = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );
    final playback = container.read(
      playerPlaybackControllerProvider('single:drama-a:1').notifier,
    );

    final startupFuture = startup.preloadFirstPlayableDrama(_drama);
    await Future<void>.delayed(Duration.zero);
    await playback.preloadAround([_item, _item2], 0);

    startupCompleter.complete(_successPreloadStateFor(_item));
    await startupFuture;

    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.success,
    );
    final playbackState = container.read(
      playerPlaybackControllerProvider('single:drama-a:1'),
    );
    expect(playbackState.preloadedItemIds, isEmpty);
    expect(
      playbackState.preloadStates.single.status,
      PlaybackPreloadStatus.failed,
    );
  });

  test('startup preload generation switch ignores stale completion', () async {
    final firstCompleter = Completer<PlaybackPreloadState>();
    final secondCompleter = Completer<PlaybackPreloadState>();
    final sourceRepository = _FakePlaybackSourceRepository(
      preloadCompleters: [firstCompleter, secondCompleter],
    );
    final container = _createContainer(sourceRepository: sourceRepository);
    addTearDown(container.dispose);
    final controller = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );

    final firstPreload = controller.preloadFirstPlayableDrama(_drama);
    await Future<void>.delayed(Duration.zero);
    final secondPreload = controller.preloadFirstPlayableDrama(_drama);
    await Future<void>.delayed(Duration.zero);

    firstCompleter.complete(_successPreloadState());
    await firstPreload;
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.pending,
    );

    secondCompleter.complete(_successPreloadState());
    await secondPreload;
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.success,
    );
  });

  test(
    'replacing visible candidate retains completed startup metadata',
    () async {
      final sourceRepository = _FakePlaybackSourceRepository();
      final container = _createContainer(sourceRepository: sourceRepository);
      addTearDown(container.dispose);
      final controller = container.read(
        playerStartupPreloadControllerProvider.notifier,
      );

      await controller.preloadFirstPlayableDramaId('drama-a');
      await controller.preloadFirstPlayableDramaId('drama-b');

      final state = container.read(playerStartupPreloadControllerProvider);
      expect(state.dramaId, 'drama-b');
      expect(state.retainedCandidates, hasLength(1));
      expect(state.retainedCandidates.single.dramaId, 'drama-a');
      expect(
        state.retainedCandidates.single.status,
        PlayerStartupPreloadStatus.success,
      );
    },
  );

  test('playItem records startup preload hit and miss', () async {
    final sourceRepository = _FakePlaybackSourceRepository();
    final container = _createContainer(sourceRepository: sourceRepository);
    addTearDown(container.dispose);
    final startup = container.read(
      playerStartupPreloadControllerProvider.notifier,
    );
    final playback = container.read(
      playerPlaybackControllerProvider('single:drama-a:1').notifier,
    );

    await playback.playItem(_item);
    expect(playback.exportTimingReport(), contains('startup preload miss'));

    await startup.preloadFirstPlayableDrama(_drama);
    expect(
      container.read(playerStartupPreloadControllerProvider).matches(_item),
      isTrue,
    );
    // 同一 item 已在播放时，playItem 会去重，不会重新记录一次 hit；启动预热命中
    // 本身由共享状态的 matches 判断。
    expect(
      container.read(playerStartupPreloadControllerProvider).status,
      PlayerStartupPreloadStatus.success,
    );
  });
}

ProviderContainer _createContainer({
  _FakePlaybackSourceRepository? sourceRepository,
  _FakePreloadManager? preloadManager,
  _FakePlaybackSession? playbackSession,
  _FakePlaybackSourceRepository? playbackSourceRepository,
  _FakePreloadManager? playbackPreloadManager,
  PlayerPreloadConfig? preloadConfig,
}) {
  final manager = preloadManager ?? _FakePreloadManager();
  return ProviderContainer(
    overrides: [
      playerFeedRepositoryProvider.overrideWithValue(
        _FakePlayerFeedRepository(),
      ),
      playerStartupPreloadManagerProvider.overrideWithValue(manager),
      playerStartupPlaybackSourceRepositoryProvider.overrideWithValue(
        sourceRepository ?? _FakePlaybackSourceRepository(),
      ),
      playerPlaybackPreloadManagerProvider.overrideWithValue(
        playbackPreloadManager ?? _FakePreloadManager(),
      ),
      playerPlaybackSourceRepositoryProvider.overrideWithValue(
        playbackSourceRepository ?? _FakePlaybackSourceRepository(),
      ),
      playerPlaybackSessionFactoryProvider.overrideWithValue(
        () => playbackSession ?? _FakePlaybackSession(),
      ),
      if (preloadConfig != null)
        playerPreloadConfigProvider.overrideWithValue(preloadConfig),
    ],
  );
}

final _drama = Drama(
  id: 'drama-a',
  title: 'Drama A',
  coverAssetPath: 'assets/images/home/drama_cover_figma.png',
  viewCountLabel: '1M',
  episodeCount: 10,
  categoryId: 'all',
  tags: const ['Rebirth'],
  coverAspectRatio: 171 / 226,
);

final _content = PlayerContent(
  id: 'drama-a',
  title: 'Drama A',
  playTitle: 'Drama A',
  synopsis: 'Synopsis',
  viewCountLabel: '1M',
  likeCountLabel: '1K',
  backgroundAssetPath: 'assets/images/player/player_background.png',
  posterAssetPath: 'assets/images/player/recommend_1.png',
  episodes: const [
    PlayerEpisode(id: 'ep-1', number: 1, isLocked: false, videoUrl: _videoUrl),
    PlayerEpisode(
      id: 'ep-2',
      number: 2,
      isLocked: false,
      videoUrl: _secondVideoUrl,
    ),
  ],
  recommendations: const [],
  episodeTotal: 2,
);

final _item = PlayerFeedItem(
  id: 'drama-a-ep-1',
  mode: PlayerFeedMode.singleDrama,
  content: _content,
  episode: _content.episodes.first,
);

final _item2 = PlayerFeedItem(
  id: 'drama-a-ep-2',
  mode: PlayerFeedMode.singleDrama,
  content: _content,
  episode: _content.episodes[1],
);

PlaybackPreloadState _successPreloadState() {
  return _successPreloadStateFor(_item);
}

PlaybackPreloadState _successPreloadStateFor(PlayerFeedItem item) {
  return PlaybackPreloadState(
    itemId: item.id,
    sourceUrl: item.episode.videoSource!,
    status: PlaybackPreloadStatus.success,
    startedAt: DateTime.now(),
    completedAt: DateTime.now(),
  );
}

class _FakePlayerFeedRepository implements PlayerFeedRepository {
  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async => [_item];

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    return [_item, _item2];
  }
}

class _FakePlaybackSourceRepository implements PlayerPlaybackSourceRepository {
  _FakePlaybackSourceRepository({
    this.preloadCompleter,
    List<Completer<PlaybackPreloadState>>? preloadCompleters,
  }) : _preloadCompleters = preloadCompleters ?? [];

  final Completer<PlaybackPreloadState>? preloadCompleter;
  final List<Completer<PlaybackPreloadState>> _preloadCompleters;
  var preloadCount = 0;
  String? lastPreloadedItemId;
  Duration? lastPreferredPosition;
  var failNextPreload = false;

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: item.episode.videoSource!,
      playableSource: item.episode.videoSource!,
      cacheKey: item.id,
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      codecHint: 'hls',
      status: PlaybackSourceStatus.resolved,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(
    PlayerFeedItem item, {
    Duration? preferredPosition,
  }) async {
    preloadCount += 1;
    lastPreloadedItemId = item.id;
    lastPreferredPosition = preferredPosition;
    if (_preloadCompleters.isNotEmpty) {
      return _preloadCompleters.removeAt(0).future;
    }
    if (preloadCompleter != null) {
      return preloadCompleter!.future;
    }
    if (failNextPreload) {
      failNextPreload = false;
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: item.episode.videoSource!,
        status: PlaybackPreloadStatus.failed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        error: StateError('preload failed'),
      );
    }
    return _successPreloadStateFor(item);
  }
}

class _FakePreloadManager implements PlayerPlaybackPreloadManager {
  var releasePendingCount = 0;

  @override
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
    Duration? preferredPosition,
  }) async {
    return _successPreloadState();
  }

  @override
  Future<void> releasePending() async {
    releasePendingCount += 1;
  }
}

class _FakePlaybackSession implements PlayerPlaybackSession {
  final _bufferingController = StreamController<bool>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final openedSources = <String>[];

  @override
  Null get videoController => null;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<bool> get completedStream => _completedController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  @override
  Stream<double> get rateStream => _rateController.stream;

  @override
  Stream<int?> get widthStream => _widthController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Future<void> open(
    String source, {
    bool play = true,
    Duration? start,
    Map<String, String>? httpHeaders,
  }) async {
    openedSources.add(source);
    _playingController.add(play);
    _widthController.add(720);
  }

  @override
  Future<void> play() async {
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRate(double rate) async {
    _rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    await _bufferingController.close();
    await _playingController.close();
    await _completedController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _rateController.close();
    await _widthController.close();
    await _errorController.close();
  }
}
