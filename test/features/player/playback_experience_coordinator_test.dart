import 'package:drama_client/features/player/application/playback_experience_coordinator.dart';
import 'package:drama_client/features/player/application/player_feed_controller.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_viewport_controller.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/application/playback_experience_state.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('experience target equality includes feed revision and episode', () {
    expect(
      const PlaybackExperienceTarget(
        itemId: 'for-you-item',
        episodeId: 'episode-1',
        feedRevision: 1,
      ),
      isNot(
        const PlaybackExperienceTarget(
          itemId: 'for-you-item',
          episodeId: 'episode-1',
          feedRevision: 2,
        ),
      ),
    );
  });

  test(
    'visible prefetched For You feed initializes its first viewport',
    () async {
      final container = _containerWithForYouItem();
      addTearDown(container.dispose);
      final feedProvider = playerFeedControllerProvider(
        PlayerPlaybackSessionKeys.forYouTab,
      );
      await container
          .read(feedProvider.notifier)
          .load(const PlayerFeedConfig.forYou());
      final item = container.read(feedProvider).currentItem!;
      final coordinator = container.read(
        playbackExperienceCoordinatorProvider(
          PlayerPlaybackSessionKeys.forYouTab,
        ).notifier,
      );

      coordinator.setVisibility(PlaybackExperienceVisibility.visible);
      await coordinator.synchronize();

      final viewport = container.read(
        playerViewportControllerProvider(PlayerPlaybackSessionKeys.forYouTab),
      );
      expect(viewport.settledIndex, 0);
      expect(viewport.settledItemId, item.id);
    },
  );

  test(
    'hidden prefetched For You feed does not initialize a viewport',
    () async {
      final container = _containerWithForYouItem();
      addTearDown(container.dispose);
      final feedProvider = playerFeedControllerProvider(
        PlayerPlaybackSessionKeys.forYouTab,
      );
      await container
          .read(feedProvider.notifier)
          .load(const PlayerFeedConfig.forYou());
      final coordinator = container.read(
        playbackExperienceCoordinatorProvider(
          PlayerPlaybackSessionKeys.forYouTab,
        ).notifier,
      );

      await coordinator.synchronize();

      expect(
        container
            .read(
              playerViewportControllerProvider(
                PlayerPlaybackSessionKeys.forYouTab,
              ),
            )
            .settledItemId,
        isNull,
      );
    },
  );

  test(
    'repeated synchronize keeps one settled generation for the same target',
    () async {
      final container = _containerWithForYouItem();
      addTearDown(container.dispose);
      final feedProvider = playerFeedControllerProvider(
        PlayerPlaybackSessionKeys.forYouTab,
      );
      await container
          .read(feedProvider.notifier)
          .load(const PlayerFeedConfig.forYou());
      final coordinator = container.read(
        playbackExperienceCoordinatorProvider(
          PlayerPlaybackSessionKeys.forYouTab,
        ).notifier,
      );

      coordinator.setVisibility(PlaybackExperienceVisibility.visible);
      await coordinator.synchronize();
      final firstGeneration = container
          .read(
            playerViewportControllerProvider(
              PlayerPlaybackSessionKeys.forYouTab,
            ),
          )
          .generation;
      await coordinator.synchronize();

      expect(
        container
            .read(
              playerViewportControllerProvider(
                PlayerPlaybackSessionKeys.forYouTab,
              ),
            )
            .generation,
        firstGeneration,
      );
    },
  );
}

ProviderContainer _containerWithForYouItem() {
  return ProviderContainer(
    overrides: [
      playerFeedRepositoryProvider.overrideWithValue(_ForYouRepository()),
    ],
  );
}

class _ForYouRepository implements PlayerFeedRepository {
  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async => [_item];

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async => [_item];
}

final _item = PlayerFeedItem(
  id: 'for-you:drama:episode',
  mode: PlayerFeedMode.forYou,
  content: PlayerContent(
    id: 'drama',
    title: 'Title',
    playTitle: 'Play title',
    synopsis: 'Synopsis',
    viewCountLabel: '1M',
    likeCountLabel: '1K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: const [],
    recommendations: const [],
  ),
  episode: const PlayerEpisode(
    id: 'episode',
    number: 1,
    isLocked: false,
    videoUrl: 'https://example.test/episode.m3u8',
  ),
);
