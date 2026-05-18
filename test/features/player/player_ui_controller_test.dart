import 'package:drama_client/features/player/application/player_chrome_auto_immersive_config_provider.dart';
import 'package:drama_client/features/player/application/player_ui_controller.dart';
import 'package:drama_client/features/player/domain/player_chrome_auto_immersive_config.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _testDelay = Duration(milliseconds: 50);

void main() {
  test('keeps paywall and episode state isolated by session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final forYouProvider = playerUiControllerProvider('for-you-tab');
    final singleProvider = playerUiControllerProvider('single:drama-a:1');

    container
        .read(forYouProvider.notifier)
        .selectEpisode(
          const PlayerEpisode(id: 'ep-8', number: 8, isLocked: true),
        );
    container
        .read(singleProvider.notifier)
        .selectEpisode(
          const PlayerEpisode(id: 'ep-2', number: 2, isLocked: false),
        );

    final forYouState = container.read(forYouProvider);
    final singleState = container.read(singleProvider);

    expect(forYouState.episodeNumber, 8);
    expect(forYouState.paywall, PlayerPaywallState.unlock);
    expect(forYouState.isPlaying, isFalse);
    expect(singleState.episodeNumber, 2);
    expect(singleState.paywall, PlayerPaywallState.hidden);
    expect(singleState.isPlaying, isTrue);
  });

  test('unavailable episode does not open paywall or start playback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = playerUiControllerProvider('single:drama-a:3');

    container
        .read(provider.notifier)
        .selectEpisode(
          const PlayerEpisode(
            id: 'ep-3',
            number: 3,
            isLocked: false,
            isAvailable: false,
          ),
        );

    final state = container.read(provider);

    expect(state.episodeNumber, 3);
    expect(state.paywall, PlayerPaywallState.hidden);
    expect(state.isPlaying, isFalse);
  });

  group('auto immersive chrome', () {
    late ProviderContainer container;
    late PlayerUiController controller;
    late final provider = playerUiControllerProvider('single:drama-a:1');

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          playerChromeAutoImmersiveConfigOverrideProvider.overrideWithValue(
            const PlayerChromeAutoImmersiveConfig(
              autoImmersiveDelay: _testDelay,
              enableAutoImmersiveForSingleDrama: true,
            ),
          ),
        ],
      );
    }

    setUp(() {
      container = createContainer();
      addTearDown(container.dispose);
      controller = container.read(provider.notifier);
      controller.configureAutoImmersiveSession(enabled: true);
    });

    test('enters immersive after delay when playing and idle', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(
        container.read(provider).chromeDisplayMode,
        PlayerChromeDisplayMode.immersive,
      );
    });

    test('does not schedule when session disabled', () async {
      controller.configureAutoImmersiveSession(enabled: false);
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('does not enter immersive when paused', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: false,
        accessPlayable: true,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('does not enter immersive when access not playable', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: false,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('does not enter immersive while modal blocking', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
        modalBlocking: true,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('does not enter immersive while seeking or scrolling', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
        isSeeking: true,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);

      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
        isSeeking: false,
        isPageScrolling: true,
      );

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('notifyUserInteraction resets timer before delay elapses', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      controller.notifyUserInteraction();

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(provider).showsChromeOverlays, isTrue);

      await Future<void>.delayed(_testDelay);
      expect(
        container.read(provider).chromeDisplayMode,
        PlayerChromeDisplayMode.immersive,
      );
    });

    test('onImmersiveVideoTap restores default chrome', () {
      controller.enterImmersiveChrome();
      expect(container.read(provider).showsChromeOverlays, isFalse);

      controller.onImmersiveVideoTap();
      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('onViewportSettled on item change shows default chrome', () {
      controller.enterImmersiveChrome();
      controller.onViewportSettled(accessPlayable: true, isItemChange: true);
      expect(container.read(provider).showsChromeOverlays, isTrue);
    });

    test('onRouteVisibilityChanged cancels timer while hidden', () async {
      controller.syncAutoImmersiveBlockers(
        playbackIsPlaying: true,
        accessPlayable: true,
      );
      controller.onRouteVisibilityChanged(false);

      await Future<void>.delayed(_testDelay + const Duration(milliseconds: 20));

      expect(container.read(provider).showsChromeOverlays, isTrue);
    });
  });
}
