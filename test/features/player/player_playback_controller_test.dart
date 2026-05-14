import 'dart:async';

import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/data/mock_playback_progress_repository.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/playback_progress_repository_provider.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_progress.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _videoUrl = 'https://v.gsuus.com/play/e5y8AAxe/index.m3u8';
const _secondVideoUrl = 'https://v.gsuus.com/play/9avRqa6a/index.m3u8';

String _playableSource(int episodeNumber) {
  return episodeNumber == 1 ? _videoUrl : _secondVideoUrl;
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

    session.shouldThrowOnOpen = false;
    await controller.playItem(item);
    await Future<void>.delayed(Duration.zero);

    expect(session.openedSources, [_playableSource(1), _playableSource(1)]);
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
      expect(state.preloadedItemIds, ['drama-a-ep-1']);
      expect(
        _preloadStatusById(state)['drama-a-ep-1'],
        PlaybackPreloadStatus.success,
      );
      expect(preloadManager.preloadCount, 1);
      expect(preloadManager.preloadedItemIds, ['drama-a-ep-1']);
      expect(session.openedSources, isEmpty);

      await controller.preloadAround(items, 3);

      state = container.read(provider);
      expect(state.preloadedItemIds, ['drama-a-ep-5']);
      expect(state.preloadedItemIds, hasLength(1));
      expect(
        _preloadStatusById(state)['drama-a-ep-5'],
        PlaybackPreloadStatus.success,
      );
      expect(preloadManager.preloadCount, 2);
    },
  );

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

  test('next item prepare opens a separate session without playing', () async {
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
    expect(preparedSession.openPlayFlags, [false]);
    expect(preparedSession.pauseCount, 1);
    expect(preparedSession.playCount, 0);
    expect(container.read(provider).status, PlayerPlaybackStatus.playing);
  });

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

      expect(currentSession.isDisposed, isTrue);
      expect(currentSession.openedSources, [_videoUrl]);
      expect(preparedSession.openedSources, [_secondVideoUrl]);
      expect(preparedSession.openPlayFlags, [false]);
      expect(preparedSession.pauseCount, 1);
      expect(preparedSession.playCount, 1);
      expect(container.read(provider).currentItemId, 'drama-a-ep-2');
      expect(container.read(provider).currentSource, _secondVideoUrl);
    },
  );

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
      var index = 0;
      final sessions = [
        currentSession,
        stalePreparedSession,
        freshPreparedSession,
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
      expect(currentSession.openedSources, [_videoUrl, _secondVideoUrl]);
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
  MockPlayerPlaybackPreloadManager? preloadManager,
  PlaybackProgressRepository? progressRepository,
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
  PlayerPlaybackSession Function() sessionFactory,
) {
  final container = ProviderContainer(
    overrides: [
      playerPlaybackSessionFactoryProvider.overrideWithValue(sessionFactory),
      playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
        () => PlayerPlaybackPrepareManager(sessionFactory: sessionFactory),
      ),
      playerPlaybackPreloadManagerProvider.overrideWithValue(
        MockPlayerPlaybackPreloadManager(preloadDelay: Duration.zero),
      ),
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
    mode: PlayerFeedMode.singleDrama,
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

class _FakePlaybackSession implements PlayerPlaybackSession {
  _FakePlaybackSession({this.openCompleter, this.shouldThrowOnOpen = false});

  final Completer<void>? openCompleter;
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
    _widthController.add(1280);
    _completedController.add(false);
    _playingController.add(play);
    _bufferingController.add(false);
  }

  void emitCompleted(bool completed) {
    _completedController.add(completed);
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
    _completedController.add(false);
  }

  @override
  Future<void> setRate(double rate) async {
    rates.add(rate);
    _rateController.add(rate);
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
