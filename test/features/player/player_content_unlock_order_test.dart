import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only the lowest-numbered locked episode is eligible for sequential unlock',
    () {
      const episode1 = PlayerEpisode(id: '1', number: 1, isLocked: false);
      const episode2 = PlayerEpisode(
        id: '2',
        number: 2,
        isLocked: true,
        unlockType: EpisodeUnlockType.coins,
      );
      const episode3 = PlayerEpisode(
        id: '3',
        number: 3,
        isLocked: true,
        unlockType: EpisodeUnlockType.coins,
      );
      final content = _content(episodes: [episode3, episode1, episode2]);

      expect(content.isSequentialUnlockEligible(episode2), isTrue);
      expect(content.isSequentialUnlockEligible(episode3), isFalse);
    },
  );

  test('an unlocked episode is not eligible for sequential unlock', () {
    const episode = PlayerEpisode(id: '1', number: 1, isLocked: false);
    final content = _content(episodes: [episode]);

    expect(content.isSequentialUnlockEligible(episode), isFalse);
  });

  test(
    'a locally unlocked earlier episode does not block the next episode',
    () {
      const episode1 = PlayerEpisode(
        id: '1',
        number: 1,
        isLocked: true,
        unlockType: EpisodeUnlockType.coins,
      );
      const episode2 = PlayerEpisode(
        id: '2',
        number: 2,
        isLocked: true,
        unlockType: EpisodeUnlockType.coins,
      );
      final content = _content(episodes: [episode1, episode2]);

      expect(
        content.isSequentialUnlockEligible(
          episode2,
          isEpisodeUnlocked: (episodeId) => episodeId == '1',
        ),
        isTrue,
      );
    },
  );
}

PlayerContent _content({required List<PlayerEpisode> episodes}) {
  return PlayerContent(
    id: 'drama-1',
    title: 'Drama',
    playTitle: 'Drama',
    synopsis: '',
    viewCountLabel: '',
    likeCountLabel: '',
    backgroundAssetPath: '',
    posterAssetPath: '',
    episodes: episodes,
    recommendations: const [],
  );
}
