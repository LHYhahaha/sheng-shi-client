import 'dart:async';

import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _videoUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
const _secondVideoUrl =
    'https://samplefile.com/samples/download/video/mp4/mp4_h264_aac_720p_sample.mp4/';

void main() {
  test('opens and switches playable episode sources', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.playItem(_item(2));

    final state = container.read(provider);
    expect(session.openedSources, [_videoUrl, _secondVideoUrl]);
    expect(state.status, PlayerPlaybackStatus.playing);
    expect(state.currentItemId, 'drama-a-ep-2');
  });

  test('keeps poster visible until source open completes', () async {
    final openCompleter = Completer<void>();
    final session = _FakePlaybackSession(openCompleter: openCompleter);
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    final playFuture = controller.playItem(_item(1));
    await Future<void>.delayed(Duration.zero);

    var state = container.read(provider);
    expect(state.status, PlayerPlaybackStatus.opening);
    expect(state.hasFirstFrame, isFalse);
    expect(session.openedSources, [_videoUrl]);

    openCompleter.complete();
    await playFuture;
    await Future<void>.delayed(Duration.zero);

    state = container.read(provider);
    expect(state.status, PlayerPlaybackStatus.playing);
    expect(state.hasFirstFrame, isTrue);
  });

  test('does not reopen unchanged source', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);
    final item = _item(1);

    await controller.playItem(item);
    await controller.playItem(item);

    expect(session.openedSources, [_videoUrl]);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

  test('open error can retry same source', () async {
    final session = _FakePlaybackSession(shouldThrowOnOpen: true);
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);
    final item = _item(1);

    await controller.playItem(item);
    expect(container.read(provider).status, PlayerPlaybackStatus.error);

    session.shouldThrowOnOpen = false;
    await controller.playItem(item);
    await Future<void>.delayed(Duration.zero);

    expect(session.openedSources, [_videoUrl, _videoUrl]);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

  test('pauses and blocks locked episodes without opening source', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(2, isLocked: true));

    final state = container.read(provider);
    expect(session.openedSources, isEmpty);
    expect(session.pauseCount, 1);
    expect(state.status, PlayerPlaybackStatus.blocked);
  });

  test('pauses unavailable episodes without opening source', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(3, isAvailable: false));

    final state = container.read(provider);
    expect(session.openedSources, isEmpty);
    expect(session.pauseCount, 1);
    expect(state.status, PlayerPlaybackStatus.unavailable);
  });

  test('toggles play pause for current source', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.togglePlay();
    await controller.togglePlay();

    expect(session.pauseCount, 1);
    expect(session.playCount, 1);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

  test(
    'updates progress state from media streams with throttled position',
    () async {
      final session = _FakePlaybackSession();
      final container = _createContainer(session);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      session.emitDuration(const Duration(seconds: 100));
      session.emitBufferedPosition(const Duration(seconds: 40));
      session.emitPosition(const Duration(milliseconds: 100));
      session.emitPosition(const Duration(milliseconds: 200));
      session.emitPosition(const Duration(milliseconds: 400));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(provider);
      expect(state.duration, const Duration(seconds: 100));
      expect(state.bufferedPosition, const Duration(seconds: 40));
      expect(state.position, const Duration(milliseconds: 400));
    },
  );

  test('seek updates preview and calls seek only on end', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    session.emitDuration(const Duration(seconds: 100));
    session.emitPosition(const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);

    controller.beginSeek();
    controller.updateSeekPreview(const Duration(seconds: 30));
    expect(container.read(provider).isSeeking, isTrue);
    expect(
      container.read(provider).seekPreviewPosition,
      const Duration(seconds: 30),
    );
    expect(session.seekedPositions, isEmpty);

    await controller.endSeek();

    expect(session.seekedPositions, [const Duration(seconds: 30)]);
    expect(session.playCount, 1);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

  test(
    'seek keeps paused state when playback was paused before dragging',
    () async {
      final session = _FakePlaybackSession();
      final container = _createContainer(session);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      session.emitDuration(const Duration(seconds: 100));
      await controller.togglePlay();

      controller.beginSeek();
      controller.updateSeekPreview(const Duration(seconds: 45));
      await controller.endSeek();

      expect(session.seekedPositions, [const Duration(seconds: 45)]);
      expect(session.playCount, 0);
      expect(container.read(provider).status, PlayerPlaybackStatus.paused);
    },
  );

  test('seek is ignored in invalid states', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    controller.beginSeek();
    controller.updateSeekPreview(const Duration(seconds: 10));
    await controller.endSeek();
    expect(session.seekedPositions, isEmpty);

    await controller.playItem(_item(2, isLocked: true));
    controller.beginSeek();
    await controller.endSeek();
    expect(session.seekedPositions, isEmpty);

    await controller.playItem(_item(3, isAvailable: false));
    controller.beginSeek();
    await controller.endSeek();
    expect(session.seekedPositions, isEmpty);

    session.shouldThrowOnOpen = true;
    await controller.playItem(_item(1));
    controller.beginSeek();
    await controller.endSeek();
    expect(session.seekedPositions, isEmpty);
  });

  test('togglePlay ignores non paused playable states', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.togglePlay();
    expect(session.playCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.idle);

    await controller.playItem(_item(2, isLocked: true));
    await controller.togglePlay();
    expect(session.playCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.blocked);

    await controller.playItem(_item(3, isAvailable: false));
    await controller.togglePlay();
    expect(session.playCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.unavailable);

    session.shouldThrowOnOpen = true;
    await controller.playItem(_item(1));
    await controller.togglePlay();
    expect(session.playCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.error);
  });

  test('togglePlay ignores opening state', () async {
    final openCompleter = Completer<void>();
    final session = _FakePlaybackSession(openCompleter: openCompleter);
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    final playFuture = controller.playItem(_item(1));
    await Future<void>.delayed(Duration.zero);

    await controller.togglePlay();
    expect(session.playCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.opening);

    openCompleter.complete();
    await playFuture;
  });

  test(
    'pauseForVisibility pauses current session and marks state paused',
    () async {
      final session = _FakePlaybackSession();
      final container = _createContainer(session);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.pauseForVisibility();

      expect(session.pauseCount, 1);
      expect(container.read(provider).status, PlayerPlaybackStatus.paused);
    },
  );

  test(
    'pauseForVisibility prevents opening source from continuing audio',
    () async {
      final openCompleter = Completer<void>();
      final session = _FakePlaybackSession(openCompleter: openCompleter);
      final container = _createContainer(session);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      final playFuture = controller.playItem(_item(1));
      await Future<void>.delayed(Duration.zero);
      await controller.pauseForVisibility();

      openCompleter.complete();
      await playFuture;

      expect(session.pauseCount, 2);
      expect(container.read(provider).status, PlayerPlaybackStatus.paused);
    },
  );

  test('disposeSession pauses and disposes current playback session', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.disposeSession();

    expect(session.pauseCount, 1);
    expect(session.isDisposed, isTrue);
    expect(container.read(provider).status, PlayerPlaybackStatus.idle);
    expect(container.read(provider).currentSource, isNull);
  });

  test(
    'disposeSession during pending open disposes and does not restore playing',
    () async {
      final openCompleter = Completer<void>();
      final session = _FakePlaybackSession(openCompleter: openCompleter);
      final container = _createContainer(session);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      final playFuture = controller.playItem(_item(1));
      await Future<void>.delayed(Duration.zero);
      await controller.disposeSession();

      openCompleter.complete();
      await playFuture;

      expect(session.isDisposed, isTrue);
      expect(container.read(provider).status, PlayerPlaybackStatus.idle);
      expect(session.playCount, 0);
    },
  );

  test('disposes media session with provider container', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session, addDisposeTearDown: false);
    container.read(playerPlaybackControllerProvider('single:drama-a:1'));

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(session.isDisposed, isTrue);
  });

  test('keeps for you and single drama playback sessions isolated', () async {
    final forYouSession = _FakePlaybackSession();
    final singleSession = _FakePlaybackSession();
    var index = 0;
    final sessions = [forYouSession, singleSession];
    final container = ProviderContainer(
      overrides: [
        playerPlaybackSessionFactoryProvider.overrideWithValue(
          () => sessions[index++],
        ),
      ],
    );
    addTearDown(container.dispose);

    final forYouProvider = playerPlaybackControllerProvider('for-you-tab');
    final singleProvider = playerPlaybackControllerProvider('single:drama-a:1');

    await container.read(forYouProvider.notifier).playItem(_item(1));
    await container.read(singleProvider.notifier).playItem(_item(2));
    await container.read(forYouProvider.notifier).togglePlay();

    expect(forYouSession.openedSources, [_videoUrl]);
    expect(singleSession.openedSources, [_secondVideoUrl]);
    expect(container.read(forYouProvider).status, PlayerPlaybackStatus.paused);
    expect(container.read(singleProvider).status, PlayerPlaybackStatus.playing);
  });

  test('keeps for you and single drama progress isolated', () async {
    final forYouSession = _FakePlaybackSession();
    final singleSession = _FakePlaybackSession();
    var index = 0;
    final sessions = [forYouSession, singleSession];
    final container = ProviderContainer(
      overrides: [
        playerPlaybackSessionFactoryProvider.overrideWithValue(
          () => sessions[index++],
        ),
      ],
    );
    addTearDown(container.dispose);

    final forYouProvider = playerPlaybackControllerProvider('for-you-tab');
    final singleProvider = playerPlaybackControllerProvider('single:drama-a:1');

    await container.read(forYouProvider.notifier).playItem(_item(1));
    await container.read(singleProvider.notifier).playItem(_item(2));
    forYouSession.emitDuration(const Duration(seconds: 80));
    forYouSession.emitPosition(const Duration(seconds: 8));
    singleSession.emitDuration(const Duration(seconds: 120));
    singleSession.emitPosition(const Duration(seconds: 30));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(forYouProvider).position, const Duration(seconds: 8));
    expect(
      container.read(singleProvider).position,
      const Duration(seconds: 30),
    );
  });

  test(
    'preload keeps at most two sessions and skips locked unavailable items',
    () async {
      final sessions = <_FakePlaybackSession>[];
      final container = ProviderContainer(
        overrides: [
          playerPlaybackSessionFactoryProvider.overrideWithValue(() {
            final session = _FakePlaybackSession();
            sessions.add(session);
            return session;
          }),
        ],
      );
      addTearDown(container.dispose);

      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);
      final items = [
        _item(1),
        _item(2),
        _item(3, isLocked: true),
        _item(4, isAvailable: false),
        _item(5),
      ];

      await controller.preloadAround(items, 1);

      var state = container.read(provider);
      expect(state.preloadedItemIds, ['drama-a-ep-1']);
      expect(sessions, hasLength(2));
      expect(sessions.last.openedSources, [_videoUrl]);

      await controller.preloadAround(items, 3);

      state = container.read(provider);
      expect(state.preloadedItemIds, ['drama-a-ep-5']);
      expect(state.preloadedItemIds, hasLength(1));
      expect(sessions[1].isDisposed, isTrue);
      expect(sessions.where((session) => !session.isDisposed), hasLength(2));
    },
  );
}

ProviderContainer _createContainer(
  _FakePlaybackSession session, {
  bool addDisposeTearDown = true,
}) {
  final container = ProviderContainer(
    overrides: [
      playerPlaybackSessionFactoryProvider.overrideWithValue(() => session),
    ],
  );
  if (addDisposeTearDown) {
    addTearDown(container.dispose);
  }
  return container;
}

PlayerFeedItem _item(
  int episodeNumber, {
  bool isLocked = false,
  bool isAvailable = true,
}) {
  final episode = PlayerEpisode(
    id: 'ep-$episodeNumber',
    number: episodeNumber,
    isLocked: isLocked,
    videoUrl: episodeNumber == 1 ? _videoUrl : _secondVideoUrl,
    isAvailable: isAvailable,
  );
  final content = PlayerContent(
    id: 'drama-a',
    title: 'Drama A',
    playTitle: 'Drama A',
    synopsis: 'Synopsis',
    viewCountLabel: '1M Views',
    likeCountLabel: '1K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: [episode],
    recommendations: const [],
  );
  return PlayerFeedItem(
    id: '${content.id}-${episode.id}',
    mode: PlayerFeedMode.singleDrama,
    content: content,
    episode: episode,
  );
}

class _FakePlaybackSession implements PlayerPlaybackSession {
  _FakePlaybackSession({this.openCompleter, this.shouldThrowOnOpen = false});

  final Completer<void>? openCompleter;
  bool shouldThrowOnOpen;
  final _bufferingController = StreamController<bool>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final openedSources = <String>[];
  final seekedPositions = <Duration>[];
  int pauseCount = 0;
  int playCount = 0;
  bool isDisposed = false;

  @override
  Null get videoController => null;

  @override
  Stream<bool> get bufferingStream => _bufferingController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<Duration> get bufferedPositionStream =>
      _bufferedPositionController.stream;

  @override
  Stream<int?> get widthStream => _widthController.stream;

  @override
  Stream<String> get errorStream => _errorController.stream;

  @override
  Future<void> open(String source, {bool play = true}) async {
    openedSources.add(source);
    _bufferingController.add(true);
    await (openCompleter?.future ?? Future<void>.value());
    if (shouldThrowOnOpen) {
      throw StateError('open failed');
    }
    _widthController.add(1280);
    _playingController.add(play);
    _bufferingController.add(false);
  }

  void emitPosition(Duration position) {
    _positionController.add(position);
  }

  void emitDuration(Duration duration) {
    _durationController.add(duration);
  }

  void emitBufferedPosition(Duration position) {
    _bufferedPositionController.add(position);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _playingController.add(false);
  }

  @override
  Future<void> play() async {
    playCount += 1;
    _playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    seekedPositions.add(position);
  }

  @override
  Future<void> dispose() async {
    if (isDisposed) {
      return;
    }
    isDisposed = true;
    await _bufferingController.close();
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferedPositionController.close();
    await _widthController.close();
    await _errorController.close();
  }
}
