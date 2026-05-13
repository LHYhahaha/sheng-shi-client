import 'package:drama_client/features/player/application/player_ui_controller.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
