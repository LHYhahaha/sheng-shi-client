import 'dart:async';

import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/data/mock_playback_progress_repository.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/playback_progress_repository_provider.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/data/player_preload_config_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_progress.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/domain/player_preload_config.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _videoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const _secondVideoUrl = 'https://test-streams.mux.dev/tos_ismc/main.m3u8';
const _thirdVideoUrl =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8';

String _playableSource(int episodeNumber) {
  return switch (episodeNumber) {
    1 => _videoUrl,
    2 => _secondVideoUrl,
    _ => _thirdVideoUrl,
  };
}

void main() {
  test('opens and switches playable episode sources', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.playItem(_item(2));

    final state = container.read(provider);
    expect(session.openedSources, [_playableSource(1), _playableSource(2)]);
    expect(state.status, PlayerPlaybackStatus.playing);
    expect(state.currentItemId, 'drama-a-ep-2');
  });

  test('hls source resolves and opens remote url', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager();
    final container = _createContainer(session, preloadManager: preloadManager);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    final playFuture = controller.playItem(_item(1));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).status, PlayerPlaybackStatus.opening);

    await playFuture;

    expect(preloadManager.preloadCount, 0);
    expect(session.openedSources, [_playableSource(1)]);
  });

  test('keeps poster visible until source open completes', () async {
    final openCompleter = Completer<void>();
    final session = _FakePlaybackSession(openCompleter: openCompleter);
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    final playFuture = controller.playItem(_item(1));
    await Future<void>.delayed(const Duration(milliseconds: 140));

    var state = container.read(provider);
    expect(state.status, PlayerPlaybackStatus.opening);
    expect(state.hasFirstFrame, isFalse);
    expect(session.openedSources, [_playableSource(1)]);

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

    expect(session.openedSources, [_playableSource(1)]);
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
    expect(
      container.read(provider).errorKind,
      PlayerPlaybackErrorKind.mediaFatal,
    );

    session.shouldThrowOnOpen = false;
    await controller.playItem(item);
    await Future<void>.delayed(Duration.zero);

    expect(session.openedSources, [_playableSource(1), _playableSource(1)]);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

  test('source resolve failure enters retryable source error state', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager(
      preloadDelay: Duration.zero,
    );
    final sourceRepository = MockPlayerPlaybackSourceRepository(
      preloadManager: preloadManager,
    )..failNextResolve = true;
    final container = _createContainer(
      session,
      preloadManager: preloadManager,
      sourceRepository: sourceRepository,
    );
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));

    final state = container.read(provider);
    expect(state.status, PlayerPlaybackStatus.error);
    expect(state.errorKind, PlayerPlaybackErrorKind.sourceResolve);
    expect(session.openedSources, isEmpty);
    expect(controller.exportTimingReport(), contains('kind=sourceResolve'));
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

  test('null source does not resolve or preload', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager();
    final container = _createContainer(session, preloadManager: preloadManager);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(6, hasSource: false));

    expect(session.openedSources, isEmpty);
    expect(preloadManager.preloadCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.unavailable);
  });

  test(
    'locked unavailable and null source items do not resolve proxy sources',
    () async {
      final session = _FakePlaybackSession();
      final sourceRepository = _CountingPlaybackSourceRepository();
      final container = _createContainer(
        session,
        sourceRepository: sourceRepository,
      );
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(2, isLocked: true));
      await controller.playItem(_item(3, isAvailable: false));
      await controller.playItem(_item(4, hasSource: false));
      await controller.preloadAround([_item(1), _item(2, isLocked: true)], 0);
      await controller.preloadAround([
        _item(1),
        _item(3, isAvailable: false),
      ], 0);
      await controller.preloadAround([_item(1), _item(4, hasSource: false)], 0);

      expect(sourceRepository.resolveCount, 0);
      expect(sourceRepository.preloadCount, 0);
      expect(session.openedSources, isEmpty);
    },
  );

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

  test('completed stream marks ended and replay clears ended', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    session.emitCompleted(true);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(provider).hasEnded, isTrue);
    expect(container.read(provider).status, PlayerPlaybackStatus.paused);

    await controller.togglePlay();

    expect(session.seekedPositions, [Duration.zero]);
    expect(session.playCount, 1);
    expect(container.read(provider).hasEnded, isFalse);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

  test('playItem and seek clear ended state', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    session.emitCompleted(true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).hasEnded, isTrue);

    await controller.playItem(_item(2));
    expect(container.read(provider).hasEnded, isFalse);

    session.emitDuration(const Duration(seconds: 100));
    session.emitCompleted(true);
    await Future<void>.delayed(Duration.zero);
    controller.beginSeek();
    controller.updateSeekPreview(const Duration(seconds: 20));
    await controller.endSeek();

    expect(container.read(provider).hasEnded, isFalse);
  });

  test('setPlaybackRate updates state and media session', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.setPlaybackRate(1.5);

    expect(session.rates, [1.5]);
    expect(container.read(provider).playbackRate, 1.5);
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
      expect(
        container.read(provider).surfaceLifecycle,
        isIn(<PlayerVideoSurfaceLifecycle>[
          PlayerVideoSurfaceLifecycle.detaching,
          PlayerVideoSurfaceLifecycle.detached,
        ]),
      );
    },
  );

  test('locked item pauses playback and detaches video surface', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.playItem(_item(2, isLocked: true));

    final state = container.read(provider);
    expect(session.pauseCount, 1);
    expect(state.status, PlayerPlaybackStatus.blocked);
    expect(state.currentItemId, 'drama-a-ep-2');
    expect(state.currentSource, isNull);
    expect(state.canMountVideoSurface, isFalse);
    expect(
      state.surfaceLifecycle,
      isIn(<PlayerVideoSurfaceLifecycle>[
        PlayerVideoSurfaceLifecycle.detaching,
        PlayerVideoSurfaceLifecycle.detached,
      ]),
    );
  });

  test('dispose path detaches surface before disposing session', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.detachSurfaceForDispose();

    var state = container.read(provider);
    expect(session.pauseCount, 1);
    expect(session.isDisposed, isFalse);
    expect(state.surfaceLifecycle, PlayerVideoSurfaceLifecycle.disposing);
    expect(state.canMountVideoSurface, isFalse);

    controller.markSurfaceDetached();
    state = container.read(provider);
    expect(state.surfaceLifecycle, PlayerVideoSurfaceLifecycle.detached);

    await controller.disposeSession();

    state = container.read(provider);
    expect(session.isDisposed, isTrue);
    expect(state.status, PlayerPlaybackStatus.idle);
    expect(state.surfaceLifecycle, PlayerVideoSurfaceLifecycle.detached);
  });

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

      expect(session.pauseCount, greaterThanOrEqualTo(1));
      expect(session.openedSources, isEmpty);
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
    expect(
      container.read(provider).surfaceLifecycle,
      PlayerVideoSurfaceLifecycle.detached,
    );
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
        playerPlaybackPreloadManagerProvider.overrideWithValue(
          MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);

    final forYouProvider = playerPlaybackControllerProvider('for-you-tab');
    final singleProvider = playerPlaybackControllerProvider('single:drama-a:1');

    await container.read(forYouProvider.notifier).playItem(_item(1));
    await container.read(singleProvider.notifier).playItem(_item(2));
    await container.read(forYouProvider.notifier).togglePlay();

    expect(forYouSession.openedSources, [_playableSource(1)]);
    expect(singleSession.openedSources, [_playableSource(2)]);
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
        playerPlaybackPreloadManagerProvider.overrideWithValue(
          MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
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

  test('single drama saves and restores mock playback progress', () async {
    final progressRepository = InMemoryPlaybackProgressRepository();
    final firstSession = _FakePlaybackSession();
    final firstContainer = _createContainer(
      firstSession,
      progressRepository: progressRepository,
      addDisposeTearDown: false,
    );
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final firstController = firstContainer.read(provider.notifier);

    await firstController.playItem(_item(1));
    firstSession.emitDuration(const Duration(seconds: 120));
    firstSession.emitPosition(const Duration(seconds: 35));
    await Future<void>.delayed(Duration.zero);
    firstContainer.dispose();

    final secondSession = _FakePlaybackSession();
    final secondContainer = _createContainer(
      secondSession,
      progressRepository: progressRepository,
      addDisposeTearDown: false,
    );
    final secondController = secondContainer.read(provider.notifier);

    await secondController.playItem(_item(1));

    expect(secondSession.seekedPositions, [const Duration(seconds: 35)]);
    expect(
      secondContainer.read(provider).position,
      const Duration(seconds: 35),
    );
    secondContainer.dispose();
  });

  test('for you does not restore cross-session progress', () async {
    final progressRepository = InMemoryPlaybackProgressRepository();
    await progressRepository.saveProgress(
      PlaybackProgress(
        itemId: 'drama-a-ep-1',
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 100),
        updatedAt: DateTime.now(),
      ),
    );
    final session = _FakePlaybackSession();
    final container = _createContainer(
      session,
      progressRepository: progressRepository,
    );
    final provider = playerPlaybackControllerProvider('for-you-tab');

    await container.read(provider.notifier).playItem(_item(1));

    expect(session.seekedPositions, isEmpty);
  });

  test(
    'keeps for you and single drama rate and ended state isolated',
    () async {
      final forYouSession = _FakePlaybackSession();
      final singleSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [forYouSession, singleSession];
      final container = ProviderContainer(
        overrides: [
          playerPlaybackSessionFactoryProvider.overrideWithValue(
            () => sessions[index++],
          ),
          playerPlaybackPreloadManagerProvider.overrideWithValue(
            MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
          ),
        ],
      );
      addTearDown(container.dispose);

      final forYouProvider = playerPlaybackControllerProvider('for-you-tab');
      final singleProvider = playerPlaybackControllerProvider(
        'single:drama-a:1',
      );

      await container.read(forYouProvider.notifier).playItem(_item(1));
      await container.read(singleProvider.notifier).playItem(_item(2));
      await container.read(forYouProvider.notifier).setPlaybackRate(1.5);
      forYouSession.emitCompleted(true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(forYouProvider).playbackRate, 1.5);
      expect(container.read(forYouProvider).hasEnded, isTrue);
      expect(container.read(singleProvider).playbackRate, 1.0);
      expect(container.read(singleProvider).hasEnded, isFalse);
    },
  );

  test(
    'preload resolves HLS source without opening playback sessions',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager();
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
      );

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
      expect(state.preloadedItemIds, ['drama-a-ep-5', 'drama-a-ep-1']);
      expect(
        _preloadStatusById(state)['drama-a-ep-1'],
        PlaybackPreloadStatus.success,
      );
      expect(
        _preloadStatusById(state)['drama-a-ep-5'],
        PlaybackPreloadStatus.success,
      );
      expect(preloadManager.preloadCount, 2);
      expect(preloadManager.preloadedItemIds, ['drama-a-ep-5', 'drama-a-ep-1']);
      expect(session.openedSources, isEmpty);

      await controller.preloadAround(items, 3);

      state = container.read(provider);
      expect(state.preloadedItemIds, ['drama-a-ep-5', 'drama-a-ep-2']);
      expect(state.preloadedItemIds, hasLength(2));
      expect(
        _preloadStatusById(state)['drama-a-ep-5'],
        PlaybackPreloadStatus.success,
      );
      expect(
        _preloadStatusById(state)['drama-a-ep-2'],
        PlaybackPreloadStatus.success,
      );
      expect(preloadManager.preloadCount, 3);
    },
  );

  test('forward HLS preload count can preload two playable items', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager();
    final container = _createContainer(
      session,
      preloadManager: preloadManager,
      preloadConfig: const PlayerPreloadConfig(
        singleDramaForwardHlsPreloadCount: 2,
        singleDramaBackwardHlsPreloadCount: 0,
      ),
    );
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.preloadAround([_item(1), _item(2), _item(3)], 0);

    final state = container.read(provider);
    expect(state.preloadedItemIds, ['drama-a-ep-2', 'drama-a-ep-3']);
    expect(preloadManager.preloadCount, 2);
    expect(session.openedSources, isEmpty);
  });

  test('skipped items do not consume effective HLS preload slots', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager();
    final container = _createContainer(
      session,
      preloadManager: preloadManager,
      preloadConfig: const PlayerPreloadConfig(
        singleDramaForwardHlsPreloadCount: 2,
        singleDramaBackwardHlsPreloadCount: 0,
      ),
    );
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.preloadAround([
      _item(1),
      _item(2, isLocked: true),
      _item(3, isAvailable: false),
      _item(4, hasSource: false),
      _item(5),
      _item(6),
    ], 0);

    final state = container.read(provider);
    expect(state.preloadedItemIds, ['drama-a-ep-5', 'drama-a-ep-6']);
    expect(preloadManager.preloadCount, 2);
  });

  test(
    'backward HLS preload count can preload previous playable item',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager();
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
        preloadConfig: const PlayerPreloadConfig(
          singleDramaForwardHlsPreloadCount: 0,
          singleDramaBackwardHlsPreloadCount: 1,
        ),
      );
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.preloadAround([_item(1), _item(2), _item(3)], 2);

      final state = container.read(provider);
      expect(state.preloadedItemIds, ['drama-a-ep-2']);
      expect(preloadManager.preloadCount, 1);
    },
  );

  test(
    'for you and single drama can use different HLS preload counts',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager();
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
        preloadConfig: const PlayerPreloadConfig(
          singleDramaForwardHlsPreloadCount: 2,
          singleDramaBackwardHlsPreloadCount: 0,
          forYouForwardHlsPreloadCount: 1,
          forYouBackwardHlsPreloadCount: 0,
        ),
      );
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.preloadAround([_item(1), _item(2), _item(3)], 0);
      expect(container.read(provider).preloadedItemIds, [
        'drama-a-ep-2',
        'drama-a-ep-3',
      ]);

      await controller.preloadAround([
        _item(1, mode: PlayerFeedMode.forYou),
        _item(2, mode: PlayerFeedMode.forYou),
        _item(3, mode: PlayerFeedMode.forYou),
      ], 0);
      expect(container.read(provider).preloadedItemIds, ['drama-a-ep-2']);
    },
  );

  test(
    'increasing HLS preload count does not expand prepared session window',
    () async {
      var index = 0;
      final sessions = List.generate(4, (_) => _FakePlaybackSession());
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(
        sessionFactory,
        preloadConfig: const PlayerPreloadConfig(
          singleDramaForwardHlsPreloadCount: 3,
          singleDramaBackwardHlsPreloadCount: 0,
          preparedForwardSessionCount: 1,
        ),
      );
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.preloadAround([
        _item(1),
        _item(2),
        _item(3),
        _item(4),
      ], 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(container.read(provider).preloadedItemIds, [
        'drama-a-ep-2',
        'drama-a-ep-3',
        'drama-a-ep-4',
      ]);
      expect(sessions[1].openedSources, [_playableSource(2)]);
      expect(sessions[2].openedSources, isEmpty);
      expect(sessions[3].openedSources, isEmpty);
    },
  );

  test('max concurrent HLS preload remains sequential', () async {
    final session = _FakePlaybackSession();
    final preloadManager = _SequentialPreloadManager();
    final container = _createContainer(
      session,
      preloadManager: preloadManager,
      preloadConfig: const PlayerPreloadConfig(
        singleDramaForwardHlsPreloadCount: 2,
        singleDramaBackwardHlsPreloadCount: 0,
        maxConcurrentHlsPreloads: 1,
      ),
    );
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    final preloadFuture = controller.preloadAround([
      _item(1),
      _item(2),
      _item(3),
    ], 0);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(preloadManager.startedItemIds, ['drama-a-ep-2']);
    preloadManager.completeNext();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(preloadManager.startedItemIds, ['drama-a-ep-2', 'drama-a-ep-3']);
    preloadManager.completeNext();
    await preloadFuture;

    expect(container.read(provider).preloadedItemIds, [
      'drama-a-ep-2',
      'drama-a-ep-3',
    ]);
  });

  test('preload pending is not counted as preloaded until success', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager(
      preloadDelay: const Duration(milliseconds: 80),
    );
    final container = _createContainer(session, preloadManager: preloadManager);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    final preloadFuture = controller.preloadAround([_item(1), _item(2)], 0);
    await Future<void>.delayed(Duration.zero);

    var state = container.read(provider);
    expect(state.preloadedItemIds, isEmpty);
    expect(
      _preloadStatusById(state)['drama-a-ep-2'],
      PlaybackPreloadStatus.pending,
    );

    await preloadFuture;

    state = container.read(provider);
    expect(state.preloadedItemIds, ['drama-a-ep-2']);
    expect(
      _preloadStatusById(state)['drama-a-ep-2'],
      PlaybackPreloadStatus.success,
    );
  });

  test(
    'refreshing same preload window keeps allowed pending preload',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = _SequentialPreloadManager();
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
      );
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);
      final items = [_item(1), _item(2)];

      final firstFuture = controller.preloadAround(items, 0);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      await controller.preloadAround(items, 0);

      expect(preloadManager.startedItemIds, ['drama-a-ep-2']);
      expect(
        _preloadStatusById(container.read(provider))['drama-a-ep-2'],
        PlaybackPreloadStatus.pending,
      );

      preloadManager.completeNext();
      await firstFuture;

      final state = container.read(provider);
      expect(state.preloadedItemIds, ['drama-a-ep-2']);
      expect(
        _preloadStatusById(state)['drama-a-ep-2'],
        PlaybackPreloadStatus.success,
      );
    },
  );

  test(
    'preload failure records failed state without touching playback',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager()
        ..failNextPreload = true;
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
      );
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.preloadAround([_item(1), _item(2)], 0);

      final state = container.read(provider);
      expect(state.status, PlayerPlaybackStatus.playing);
      expect(state.preloadedItemIds, isEmpty);
      expect(
        _preloadStatusById(state)['drama-a-ep-2'],
        PlaybackPreloadStatus.failed,
      );
    },
  );

  test(
    'locked unavailable and null source items do not create preload state',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager();
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
      );
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.preloadAround([
        _item(1),
        _item(2, isLocked: true),
        _item(3, isAvailable: false),
        _item(4, hasSource: false),
      ], 0);

      final state = container.read(provider);
      expect(state.preloadedItemIds, isEmpty);
      expect(state.preloadStates, isEmpty);
      expect(preloadManager.preloadCount, 0);
    },
  );

  test('dispose releases pending preload and ignores late writes', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager(
      preloadDelay: const Duration(milliseconds: 80),
    );
    final container = _createContainer(
      session,
      preloadManager: preloadManager,
      addDisposeTearDown: false,
    );
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);
    final preloadFuture = controller.preloadAround([_item(1), _item(2)], 0);

    await Future<void>.delayed(Duration.zero);
    await controller.disposeSession();
    await preloadFuture;

    expect(preloadManager.releasePendingCount, greaterThan(0));
    expect(container.read(provider).preloadedItemIds, isEmpty);
    expect(container.read(provider).preloadStates, isEmpty);
    container.dispose();
  });

  test(
    'pauseForVisibility releases pending preload without disposing playback',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager(
        preloadDelay: const Duration(milliseconds: 80),
      );
      final container = _createContainer(
        session,
        preloadManager: preloadManager,
        addDisposeTearDown: false,
      );
      final provider = playerPlaybackControllerProvider('for-you-tab');
      final controller = container.read(provider.notifier);

      final preloadFuture = controller.preloadAround([_item(1), _item(2)], 0);
      await Future<void>.delayed(Duration.zero);
      await controller.pauseForVisibility();
      await preloadFuture;

      expect(preloadManager.releasePendingCount, greaterThan(0));
      expect(container.read(provider).preloadedItemIds, isEmpty);
      expect(
        _preloadStatusById(container.read(provider))['drama-a-ep-2'],
        PlaybackPreloadStatus.cancelled,
      );
      expect(session.isDisposed, isFalse);
      container.dispose();
    },
  );

  test('fast preload generation switch prevents stale success write', () async {
    final session = _FakePlaybackSession();
    final preloadManager = MockPlayerPlaybackPreloadManager(
      preloadDelay: const Duration(milliseconds: 80),
    );
    final container = _createContainer(session, preloadManager: preloadManager);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);
    final firstFuture = controller.preloadAround([_item(1), _item(2)], 0);

    await Future<void>.delayed(Duration.zero);
    expect(
      _preloadStatusById(container.read(provider))['drama-a-ep-2'],
      PlaybackPreloadStatus.pending,
    );

    await controller.preloadAround([_item(3), _item(4), _item(5)], 1);
    await firstFuture;

    final state = container.read(provider);
    expect(state.preloadedItemIds, ['drama-a-ep-5', 'drama-a-ep-3']);
    expect(
      _preloadStatusById(state)['drama-a-ep-2'],
      PlaybackPreloadStatus.cancelled,
    );
    expect(
      _preloadStatusById(state)['drama-a-ep-5'],
      PlaybackPreloadStatus.success,
    );
    expect(
      _preloadStatusById(state)['drama-a-ep-3'],
      PlaybackPreloadStatus.success,
    );
  });

  test('keeps for you and single drama preload state isolated', () async {
    final forYouSession = _FakePlaybackSession();
    final singleSession = _FakePlaybackSession();
    var index = 0;
    final sessions = [forYouSession, singleSession];
    final preloadManager = MockPlayerPlaybackPreloadManager();
    final container = ProviderContainer(
      overrides: [
        playerPlaybackSessionFactoryProvider.overrideWithValue(
          () => sessions[index++],
        ),
        playerPlaybackPreloadManagerProvider.overrideWithValue(preloadManager),
      ],
    );
    addTearDown(container.dispose);
    final forYouProvider = playerPlaybackControllerProvider('for-you-tab');
    final singleProvider = playerPlaybackControllerProvider('single:drama-a:1');

    await container.read(forYouProvider.notifier).preloadAround([
      _item(1),
      _item(2),
    ], 0);
    await container.read(singleProvider.notifier).preloadAround([
      _item(3),
      _item(4),
      _item(5),
    ], 1);

    expect(container.read(forYouProvider).preloadedItemIds, ['drama-a-ep-2']);
    expect(container.read(singleProvider).preloadedItemIds, [
      'drama-a-ep-5',
      'drama-a-ep-3',
    ]);
    expect(forYouSession.openedSources, isEmpty);
    expect(singleSession.openedSources, isEmpty);
  });

  test(
    'next item prepare warms a muted separate session without audio',
    () async {
      final currentSession = _FakePlaybackSession();
      final preparedSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [currentSession, preparedSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.preloadAround([_item(1), _item(2)], 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(currentSession.openedSources, [_videoUrl]);
      expect(preparedSession.openedSources, [_secondVideoUrl]);
      expect(preparedSession.openPlayFlags, [true]);
      expect(preparedSession.volumes, [0, 100]);
      expect(preparedSession.pauseCount, 1);
      expect(preparedSession.playCount, 0);
      expect(container.read(provider).status, PlayerPlaybackStatus.playing);
    },
  );

  test(
    'prepared item takeover avoids duplicate open on current session',
    () async {
      final currentSession = _FakePlaybackSession();
      final preparedSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [currentSession, preparedSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.preloadAround([_item(1), _item(2)], 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await controller.playItem(_item(2));

      expect(currentSession.isDisposed, isFalse);
      expect(currentSession.pauseCount, greaterThanOrEqualTo(1));
      expect(currentSession.openedSources, [_videoUrl]);
      expect(preparedSession.openedSources, [_secondVideoUrl]);
      expect(preparedSession.openPlayFlags, [true]);
      expect(preparedSession.volumes, [0, 100, 100]);
      expect(preparedSession.pauseCount, 1);
      expect(preparedSession.playCount, 1);
      expect(container.read(provider).currentItemId, 'drama-a-ep-2');
      expect(container.read(provider).currentSource, _secondVideoUrl);
    },
  );

  test('same source different item is still prepared as candidate', () async {
    final currentSession = _FakePlaybackSession();
    final preparedSession = _FakePlaybackSession();
    var index = 0;
    final sessions = [currentSession, preparedSession];
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([
      _item(1),
      _item(2, videoUrl: _videoUrl),
    ], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(preparedSession.openedSources, [_videoUrl]);
    expect(
      controller.exportTimingReport(),
      contains('candidates=drama-a-ep-2'),
    );
    expect(controller.exportTimingReport(), isNot(contains('current_source')));
  });

  test(
    'normal fallback open retains old current for previous swipe hit',
    () async {
      final firstSession = _FakePlaybackSession();
      final secondSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [firstSession, secondSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      firstSession.emitDuration(const Duration(seconds: 120));
      firstSession.emitPosition(const Duration(seconds: 37));
      firstSession.emitBufferedPosition(const Duration(seconds: 52));
      await Future<void>.delayed(Duration.zero);
      await controller.playItem(_item(2));
      await controller.playItem(_item(1));

      expect(firstSession.openedSources, [_videoUrl]);
      expect(secondSession.openedSources, [_secondVideoUrl]);
      expect(firstSession.pauseCount, greaterThanOrEqualTo(1));
      expect(firstSession.playCount, 1);
      expect(secondSession.pauseCount, greaterThanOrEqualTo(1));
      expect(container.read(provider).currentItemId, 'drama-a-ep-1');
      expect(container.read(provider).position, const Duration(seconds: 37));
      expect(
        controller.exportTimingReport(),
        contains('retain current before normal open'),
      );
      expect(controller.exportTimingReport(), contains('retain current done'));
      expect(
        controller.exportTimingReport(),
        contains('retained hit previous'),
      );
      final ep1ResolveCount = controller.timingEvents
          .where(
            (event) =>
                event.name == 'source resolve start' &&
                event.itemId == 'drama-a-ep-1',
          )
          .length;
      final ep1OpenCount = controller.timingEvents
          .where(
            (event) =>
                event.name == 'media open start' &&
                event.itemId == 'drama-a-ep-1',
          )
          .length;
      expect(ep1ResolveCount, 1);
      expect(ep1OpenCount, 1);
    },
  );

  test(
    'normal open failure keeps retained previous session reusable',
    () async {
      final firstSession = _FakePlaybackSession();
      final failingSession = _FakePlaybackSession(shouldThrowOnOpen: true);
      var index = 0;
      final sessions = [firstSession, failingSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.playItem(_item(2));
      expect(container.read(provider).status, PlayerPlaybackStatus.error);

      await controller.playItem(_item(1));

      expect(firstSession.openedSources, [_videoUrl]);
      expect(failingSession.openedSources, [_secondVideoUrl]);
      expect(failingSession.isDisposed, isTrue);
      expect(container.read(provider).currentItemId, 'drama-a-ep-1');
      expect(
        controller.exportTimingReport(),
        contains('retained hit previous'),
      );
    },
  );

  test(
    'previous played session is reused with progress when swiping back',
    () async {
      final firstSession = _FakePlaybackSession();
      final secondSession = _FakePlaybackSession();
      final nextSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [firstSession, secondSession, nextSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      firstSession.emitDuration(const Duration(seconds: 120));
      firstSession.emitPosition(const Duration(seconds: 42));
      firstSession.emitBufferedPosition(const Duration(seconds: 50));
      await Future<void>.delayed(Duration.zero);
      await controller.preloadAround([_item(1), _item(2)], 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await controller.playItem(_item(2));
      await controller.preloadAround([_item(1), _item(2)], 1);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await controller.playItem(_item(1));

      expect(firstSession.openedSources, [_videoUrl]);
      expect(secondSession.openedSources, [_secondVideoUrl]);
      expect(nextSession.openedSources, isEmpty);
      expect(firstSession.playCount, 1);
      expect(firstSession.pauseCount, greaterThanOrEqualTo(1));
      expect(secondSession.isDisposed, isFalse);
      expect(container.read(provider).currentItemId, 'drama-a-ep-1');
      expect(container.read(provider).position, const Duration(seconds: 42));
      expect(container.read(provider).duration, const Duration(seconds: 120));
      expect(
        container.read(provider).bufferedPosition,
        const Duration(seconds: 50),
      );
      expect(
        controller.timingEvents.map((event) => event.name),
        contains('retained hit previous'),
      );
    },
  );

  test('session window keeps at most previous and next sessions', () async {
    final sessions = [
      _FakePlaybackSession(),
      _FakePlaybackSession(),
      _FakePlaybackSession(),
      _FakePlaybackSession(),
    ];
    var index = 0;
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([_item(1), _item(2), _item(3)], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await controller.playItem(_item(2));
    await controller.preloadAround([
      _item(1),
      _item(2),
      _item(3, videoUrl: 'https://cdn.example.test/ep3.m3u8'),
    ], 1);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await controller.playItem(
      _item(3, videoUrl: 'https://cdn.example.test/ep3.m3u8'),
    );
    await controller.preloadAround([
      _item(1),
      _item(2),
      _item(3, videoUrl: 'https://cdn.example.test/ep3.m3u8'),
    ], 2);

    expect(sessions[0].isDisposed, isTrue);
    expect(sessions[1].isDisposed, isFalse);
    expect(sessions[2].isDisposed, isFalse);
    expect(container.read(provider).currentItemId, 'drama-a-ep-3');
  });

  test('exports bounded playback timing report', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([_item(1), _item(2)], 0);

    expect(
      controller.timingEvents.map((event) => event.name),
      containsAll([
        'window miss fallback open',
        'play item request',
        'list entry normal open',
        'source resolve start',
        'source resolve end',
        'media open start',
        'session play called',
        'media open end',
        'first frame received',
        'preload candidates',
        'preload start',
        'preload end',
      ]),
    );
    expect(controller.exportTimingReport(), contains('media open end'));
    expect(
      controller.exportTimingReport(),
      contains('session=single:drama-a:1'),
    );
    expect(controller.exportTimingReport(), contains('elapsed='));
    expect(controller.exportTimingReport(), contains('trace='));
    expect(controller.exportTimingReport(), contains('sourceLabel=mux-fast'));
    expect(controller.exportTimingReport(), contains('sinceTraceStartMs='));
    expect(controller.exportTimingReport(), contains('sinceUserActionMs='));
    expect(controller.exportTimingReport(), contains('windowItems='));
    expect(controller.exportTimingReport(), contains('requestedItemId='));
  });

  test('user action trigger is attached to next playback trace', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    controller.recordPlaybackUserAction(
      'PageView page changed',
      trigger: 'swipe_next',
      fromItemId: 'drama-a-ep-1',
      toItemId: 'drama-a-ep-2',
      direction: 'next',
      fromIndex: 0,
      toIndex: 1,
      occurredAt: DateTime.now().subtract(const Duration(milliseconds: 30)),
    );
    await controller.playItem(_item(2));

    final report = controller.exportTimingReport();
    expect(report, contains('trigger=swipe_next'));
    expect(report, contains('fromItemId=drama-a-ep-1'));
    expect(report, contains('toItemId=drama-a-ep-2'));
    expect(report, contains('sinceUserActionMs='));
  });

  test('prepared first frame can arrive after prepare open returns', () async {
    final currentSession = _FakePlaybackSession();
    final preparedSession = _FakePlaybackSession(emitWidthOnOpen: false);
    var index = 0;
    final sessions = [currentSession, preparedSession];
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([_item(1), _item(2)], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    preparedSession.emitWidth(1280);
    await Future<void>.delayed(Duration.zero);
    await controller.playItem(_item(2));

    expect(preparedSession.openedSources, [_secondVideoUrl]);
    expect(preparedSession.playCount, 1);
    expect(container.read(provider).hasFirstFrame, isTrue);
    expect(controller.exportTimingReport(), contains('prepared hit next'));
    expect(controller.exportTimingReport(), contains('take window session'));
    expect(controller.exportTimingReport(), contains('prepare manager take'));
    expect(controller.exportTimingReport(), contains('firstFrameReady=true'));
  });

  test(
    'prepared playback advanced without width is reused without fallback open',
    () async {
      final currentSession = _FakePlaybackSession();
      final preparedSession = _FakePlaybackSession(emitWidthOnOpen: false);
      final fallbackSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [currentSession, preparedSession, fallbackSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.preloadAround([_item(1), _item(2)], 0);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      preparedSession.emitPosition(const Duration(milliseconds: 400));
      await Future<void>.delayed(Duration.zero);
      await controller.playItem(_item(2));

      expect(preparedSession.openedSources, [_secondVideoUrl]);
      expect(preparedSession.playCount, 1);
      expect(fallbackSession.openedSources, isEmpty);
      expect(container.read(provider).hasFirstFrame, isFalse);
      expect(container.read(provider).isBuffering, isTrue);
      expect(controller.exportTimingReport(), contains('prepared hit next'));
      expect(
        controller.exportTimingReport(),
        contains('playbackAdvanced=true'),
      );
    },
  );

  test(
    'prepared takeover cancels warm-up pause before current playback',
    () async {
      final currentSession = _FakePlaybackSession();
      final preparedSession = _FakePlaybackSession(emitWidthOnOpen: false);
      var index = 0;
      final sessions = [currentSession, preparedSession];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(
        sessionFactory,
        warmUpTimeout: const Duration(milliseconds: 120),
      );
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      await controller.preloadAround([_item(1), _item(2)], 0);
      await controller.playItem(_item(2));
      await Future<void>.delayed(const Duration(milliseconds: 180));

      expect(preparedSession.openPlayFlags, [true]);
      expect(preparedSession.volumes, [0, 100]);
      expect(preparedSession.pauseCount, 0);
      expect(preparedSession.playCount, 1);
      expect(container.read(provider).status, PlayerPlaybackStatus.playing);
      expect(controller.exportTimingReport(), contains('prepared hit next'));
      expect(
        controller.exportTimingReport(),
        contains('prepare warm-up cancelled'),
      );
    },
  );

  test('logs playback advancing before first frame diagnostics', () async {
    final session = _FakePlaybackSession(emitWidthOnOpen: false);
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    session.emitPlaying(true);
    await Future<void>.delayed(Duration.zero);
    session.emitPosition(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    controller.recordVideoSurfaceShownBeforeFirstFrame(
      itemId: 'drama-a-ep-1',
      source: _videoUrl,
    );

    final report = controller.exportTimingReport();
    expect(report, contains('playing event while hasFirstFrame=false'));
    expect(report, contains('position advancing while hasFirstFrame=false'));
    expect(report, contains('video surface shown before firstFrame'));
  });

  test('transient HLS error after first frame stays recoverable', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    session.emitPosition(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);
    session.emitError('tcp: ffurl_read returned segment 00001.ts');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(provider);
    expect(state.status, PlayerPlaybackStatus.playing);
    expect(state.hasFirstFrame, isTrue);
    expect(state.isBuffering, isTrue);
    expect(state.errorKind, PlayerPlaybackErrorKind.recoverableNetwork);
    expect(controller.exportTimingReport(), contains('recoverable error'));
    expect(
      controller.exportTimingReport(),
      contains('kind=recoverableNetwork'),
    );
  });

  test('fatal media error still enters retryable error state', () async {
    final session = _FakePlaybackSession();
    final container = _createContainer(session);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    session.emitError('fatal invalid media');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(provider);
    expect(state.status, PlayerPlaybackStatus.error);
    expect(state.hasFirstFrame, isFalse);
    expect(state.errorKind, PlayerPlaybackErrorKind.mediaFatal);
    expect(controller.exportTimingReport(), contains('kind=mediaFatal'));
  });

  test('duplicate prepare requests for same item are ignored', () async {
    final currentSession = _FakePlaybackSession();
    final prepareCompleter = Completer<void>();
    final preparedSession = _FakePlaybackSession(
      openCompleter: prepareCompleter,
    );
    final extraSession = _FakePlaybackSession();
    var index = 0;
    final sessions = [currentSession, preparedSession, extraSession];
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    final firstPrepare = controller.preloadAround([_item(1), _item(2)], 0);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final duplicatePrepare = controller.preloadAround([_item(1), _item(2)], 0);
    await Future<void>.delayed(Duration.zero);

    expect(preparedSession.openedSources, [_secondVideoUrl]);
    expect(extraSession.openedSources, isEmpty);

    prepareCompleter.complete();
    await firstPrepare;
    await duplicatePrepare;
    await controller.playItem(_item(2));

    expect(preparedSession.playCount, 1);
    expect(extraSession.openedSources, isEmpty);
    expect(
      controller.timingEvents.map((event) => event.name),
      contains('prepare skipped duplicate'),
    );
  });

  test('hidden and dispose release prepared sessions', () async {
    final currentSession = _FakePlaybackSession();
    final preparedSession = _FakePlaybackSession();
    var index = 0;
    final sessions = [currentSession, preparedSession];
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    final provider = playerPlaybackControllerProvider('for-you-tab');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([_item(1), _item(2)], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await controller.pauseForVisibility();

    expect(preparedSession.isDisposed, isTrue);
    expect(currentSession.isDisposed, isFalse);
    container.dispose();
  });

  test('locked unavailable and null source items are not prepared', () async {
    final currentSession = _FakePlaybackSession();
    var createCount = 0;
    PlayerPlaybackSession sessionFactory() {
      createCount += 1;
      return currentSession;
    }

    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([
      _item(1),
      _item(2, isLocked: true),
      _item(3, isAvailable: false),
      _item(4, hasSource: false),
    ], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(createCount, 1);
    expect(currentSession.openedSources, [_videoUrl]);
  });

  test('prepare failure does not affect current playback', () async {
    final currentSession = _FakePlaybackSession();
    final failingPreparedSession = _FakePlaybackSession(
      shouldThrowOnOpen: true,
    );
    var index = 0;
    final sessions = [currentSession, failingPreparedSession];
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final provider = playerPlaybackControllerProvider('single:drama-a:1');
    final controller = container.read(provider.notifier);

    await controller.playItem(_item(1));
    await controller.preloadAround([_item(1), _item(2)], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
    expect(currentSession.isDisposed, isFalse);
    expect(failingPreparedSession.isDisposed, isTrue);
  });

  test(
    'fast swipe stale prepared session is released and not taken over',
    () async {
      final currentSession = _FakePlaybackSession();
      final stalePrepareCompleter = Completer<void>();
      final stalePreparedSession = _FakePlaybackSession(
        openCompleter: stalePrepareCompleter,
      );
      final freshPreparedSession = _FakePlaybackSession();
      final normalFallbackSession = _FakePlaybackSession();
      var index = 0;
      final sessions = [
        currentSession,
        stalePreparedSession,
        freshPreparedSession,
        normalFallbackSession,
      ];
      PlayerPlaybackSession sessionFactory() => sessions[index++];
      final container = _createPrepareContainer(sessionFactory);
      addTearDown(container.dispose);
      final provider = playerPlaybackControllerProvider('single:drama-a:1');
      final controller = container.read(provider.notifier);

      await controller.playItem(_item(1));
      unawaited(controller.preloadAround([_item(1), _item(2)], 0));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await controller.preloadAround([
        _item(3, videoUrl: 'https://cdn.example.test/ep3.m3u8'),
        _item(4, videoUrl: 'https://cdn.example.test/ep4.m3u8'),
      ], 0);
      stalePrepareCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await controller.playItem(_item(2));

      expect(stalePreparedSession.isDisposed, isTrue);
      expect(currentSession.openedSources, [_videoUrl]);
      expect(normalFallbackSession.openedSources, [_secondVideoUrl]);
      expect(freshPreparedSession.openedSources, [
        'https://cdn.example.test/ep4.m3u8',
      ]);
    },
  );

  test('for you and single drama prepared sessions stay isolated', () async {
    final sessions = [
      _FakePlaybackSession(),
      _FakePlaybackSession(),
      _FakePlaybackSession(),
      _FakePlaybackSession(),
    ];
    var index = 0;
    PlayerPlaybackSession sessionFactory() => sessions[index++];
    final container = _createPrepareContainer(sessionFactory);
    addTearDown(container.dispose);
    final forYouProvider = playerPlaybackControllerProvider('for-you-tab');
    final singleProvider = playerPlaybackControllerProvider('single:drama-a:1');

    await container.read(forYouProvider.notifier).playItem(_item(1));
    await container.read(singleProvider.notifier).playItem(_item(2));
    await container.read(forYouProvider.notifier).preloadAround([
      _item(1),
      _item(2),
    ], 0);
    await container.read(singleProvider.notifier).preloadAround([
      _item(2),
      _item(3, videoUrl: 'https://cdn.example.test/ep3.m3u8'),
    ], 0);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(sessions[2].openedSources, [_secondVideoUrl]);
    expect(sessions[3].openedSources, ['https://cdn.example.test/ep3.m3u8']);
    expect(container.read(forYouProvider).currentItemId, 'drama-a-ep-1');
    expect(container.read(singleProvider).currentItemId, 'drama-a-ep-2');
  });
}

ProviderContainer _createContainer(
  _FakePlaybackSession session, {
  bool addDisposeTearDown = true,
  PlayerPlaybackPreloadManager? preloadManager,
  PlaybackProgressRepository? progressRepository,
  PlayerPlaybackSourceRepository? sourceRepository,
  PlayerPreloadConfig? preloadConfig,
}) {
  final playbackCacheManager =
      preloadManager ??
      MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero);
  final container = ProviderContainer(
    overrides: [
      playerPlaybackSessionFactoryProvider.overrideWithValue(() => session),
      playerPlaybackPreloadManagerProvider.overrideWithValue(
        playbackCacheManager,
      ),
      playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
        NoopPlayerPlaybackPrepareManager.new,
      ),
      if (sourceRepository != null)
        playerPlaybackSourceRepositoryProvider.overrideWithValue(
          sourceRepository,
        ),
      if (preloadConfig != null)
        playerPreloadConfigProvider.overrideWithValue(preloadConfig),
      if (progressRepository != null)
        playbackProgressRepositoryProvider.overrideWithValue(
          progressRepository,
        ),
    ],
  );
  if (addDisposeTearDown) {
    addTearDown(container.dispose);
  }
  return container;
}

ProviderContainer _createPrepareContainer(
  PlayerPlaybackSession Function() sessionFactory, {
  Duration warmUpTimeout = const Duration(milliseconds: 4000),
  PlayerPreloadConfig? preloadConfig,
}) {
  final container = ProviderContainer(
    overrides: [
      playerPlaybackSessionFactoryProvider.overrideWithValue(sessionFactory),
      playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
        () => PlayerPlaybackPrepareManager(
          sessionFactory: sessionFactory,
          warmUpTimeout: warmUpTimeout,
        ),
      ),
      playerPlaybackPreloadManagerProvider.overrideWithValue(
        MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
      ),
      if (preloadConfig != null)
        playerPreloadConfigProvider.overrideWithValue(preloadConfig),
    ],
  );
  return container;
}

PlayerFeedItem _item(
  int episodeNumber, {
  bool isLocked = false,
  bool isAvailable = true,
  bool hasSource = true,
  String? videoUrl,
  PlayerFeedMode mode = PlayerFeedMode.singleDrama,
}) {
  final episode = PlayerEpisode(
    id: 'ep-$episodeNumber',
    number: episodeNumber,
    isLocked: isLocked,
    videoUrl:
        videoUrl ??
        (hasSource ? (episodeNumber == 1 ? _videoUrl : _secondVideoUrl) : null),
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
    mode: mode,
    content: content,
    episode: episode,
  );
}

Map<String, PlaybackPreloadStatus> _preloadStatusById(
  PlayerPlaybackState state,
) {
  return {
    for (final preloadState in state.preloadStates)
      preloadState.itemId: preloadState.status,
  };
}

class _CountingPlaybackSourceRepository
    implements PlayerPlaybackSourceRepository {
  var resolveCount = 0;
  var preloadCount = 0;

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    resolveCount += 1;
    final source = item.episode.videoSource!;
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: source,
      playableSource: source,
      cacheKey: source,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      codecHint: 'hls',
      status: PlaybackSourceStatus.resolved,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(PlayerFeedItem item) async {
    preloadCount += 1;
    return PlaybackPreloadState(
      itemId: item.id,
      sourceUrl: item.episode.videoSource!,
      status: PlaybackPreloadStatus.success,
      startedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
  }
}

class _SequentialPreloadManager implements PlayerPlaybackPreloadManager {
  final startedItemIds = <String>[];
  final _pending = <_PendingPreload>[];

  @override
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
  }) {
    startedItemIds.add(item.id);
    final completer = Completer<PlaybackPreloadState>();
    _pending.add(_PendingPreload(item, source, completer));
    return completer.future;
  }

  void completeNext() {
    final pending = _pending.removeAt(0);
    pending.completer.complete(
      PlaybackPreloadState(
        itemId: pending.item.id,
        sourceUrl: pending.source.playableSource,
        status: PlaybackPreloadStatus.success,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> releasePending() async {
    for (final pending in _pending) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete(
          PlaybackPreloadState(
            itemId: pending.item.id,
            sourceUrl: pending.source.playableSource,
            status: PlaybackPreloadStatus.cancelled,
            startedAt: DateTime.now(),
            completedAt: DateTime.now(),
          ),
        );
      }
    }
    _pending.clear();
  }
}

class _PendingPreload {
  const _PendingPreload(this.item, this.source, this.completer);

  final PlayerFeedItem item;
  final PlaybackSource source;
  final Completer<PlaybackPreloadState> completer;
}

class _FakePlaybackSession implements PlayerPlaybackSession {
  _FakePlaybackSession({
    this.openCompleter,
    this.shouldThrowOnOpen = false,
    this.emitWidthOnOpen = true,
  });

  final Completer<void>? openCompleter;
  final bool emitWidthOnOpen;
  bool shouldThrowOnOpen;
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
  final openPlayFlags = <bool>[];
  final seekedPositions = <Duration>[];
  final rates = <double>[];
  final volumes = <double>[];
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
  Future<void> open(String source, {bool play = true}) async {
    openedSources.add(source);
    openPlayFlags.add(play);
    _bufferingController.add(true);
    await (openCompleter?.future ?? Future<void>.value());
    if (shouldThrowOnOpen) {
      throw StateError('open failed');
    }
    if (emitWidthOnOpen) {
      _widthController.add(1280);
    }
    _completedController.add(false);
    _playingController.add(play);
    _bufferingController.add(false);
  }

  void emitCompleted(bool completed) {
    _completedController.add(completed);
  }

  void emitPlaying(bool isPlaying) {
    _playingController.add(isPlaying);
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

  void emitWidth(int width) {
    _widthController.add(width);
  }

  void emitError(String error) {
    _errorController.add(error);
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
    _completedController.add(false);
  }

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
    _rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> dispose() async {
    if (isDisposed) {
      return;
    }
    isDisposed = true;
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
