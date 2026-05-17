import 'dart:async';

import 'package:drama_client/bootstrap/feature_session_cleanup.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_playback_prepare_manager.dart';
import 'package:drama_client/features/player/application/player_session_cleanup.dart';
import 'package:drama_client/features/player/application/player_session_controller.dart';
import 'package:drama_client/features/player/application/player_session_registry.dart';
import 'package:drama_client/features/player/data/mock_playback_progress_repository.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/playback_progress_repository_provider.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/data/player_preload_config_provider.dart';
import 'package:drama_client/features/player/domain/player_preload_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runPlayerSessionCleanup pauses and disposes playback session',
    () async {
      final session = _FakePlaybackSession();
      final preloadManager = MockPlayerPlaybackPreloadManager(
        preloadDelay: Duration.zero,
      );
      final container = ProviderContainer(
        overrides: [
          playerPlaybackSessionFactoryProvider.overrideWithValue(() => session),
          playerPlaybackPreloadManagerProvider.overrideWithValue(
            preloadManager,
          ),
          playerPlaybackPrepareManagerFactoryProvider.overrideWithValue(
            NoopPlayerPlaybackPrepareManager.new,
          ),
          playerPlaybackSourceRepositoryProvider.overrideWithValue(
            MockPlayerPlaybackSourceRepository(preloadManager: preloadManager),
          ),
          playbackProgressRepositoryProvider.overrideWithValue(
            InMemoryPlaybackProgressRepository(),
          ),
          playerPreloadConfigProvider.overrideWithValue(
            const PlayerPreloadConfig(
              homeStartupPreloadCount: 0,
              singleDramaForwardHlsPreloadCount: 0,
              singleDramaBackwardHlsPreloadCount: 0,
              forYouForwardHlsPreloadCount: 0,
              forYouBackwardHlsPreloadCount: 0,
              preparedForwardSessionCount: 0,
              retainedBackwardSessionCount: 0,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(featureSessionCleanupRegistrationProvider);

      const sessionKey = PlayerPlaybackSessionKeys.forYouTab;
      container.read(playerPlaybackControllerProvider(sessionKey));

      await runPlayerSessionCleanupWith(
        read: <T>(dynamic provider) => container.read(provider),
        invalidate: (dynamic provider) => container.invalidate(provider),
      );

      expect(session.pauseCount, greaterThan(0));
      expect(session.isDisposed, isTrue);
      final state = container.read(
        playerPlaybackControllerProvider(sessionKey),
      );
      expect(state.status, PlayerPlaybackStatus.idle);
      expect(state.currentSource, isNull);
    },
  );

  test('session cleanup registry tracks active session keys', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final registry = container.read(playerSessionRegistryProvider.notifier);
    expect(container.read(playerSessionRegistryProvider), isEmpty);

    registry.register('test-session');
    expect(
      container.read(playerSessionRegistryProvider),
      contains('test-session'),
    );

    registry.unregister('test-session');
    expect(container.read(playerSessionRegistryProvider), isEmpty);
  });
}

class _FakePlaybackSession implements PlayerPlaybackSession {
  int pauseCount = 0;
  bool isDisposed = false;

  final _bufferingController = StreamController<bool>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _rateController = StreamController<double>.broadcast();
  final _widthController = StreamController<int?>.broadcast();
  final _errorController = StreamController<String>.broadcast();

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
  Future<void> open(String source, {bool play = true}) async {}

  @override
  Future<void> pause() async {
    pauseCount += 1;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
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
