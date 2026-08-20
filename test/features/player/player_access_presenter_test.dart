import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/entitlement/domain/user_entitlement_state.dart';
import 'package:drama_client/features/player/application/player_access_presenter.dart';
import 'package:drama_client/features/player/domain/player_access_presentation.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'revokes a stale temporary playable grant after entitlement refresh',
    () {
      final item = _lockedCoinItem();
      final expiredMembership = const UserEntitlementState(
        isGuest: false,
        isMember: false,
        coinBalance: 47,
        autoUnlockEnabled: false,
        unlockedEpisodeIds: {},
      );
      final temporarilyPlayable = const PlayerAccessPresenter()
          .withPlayableItem(item.id);

      expect(
        temporarilyPlayable.presentationFor(item, expiredMembership),
        PlayerAccessPresentationState.playable,
      );
      expect(
        temporarilyPlayable
            .withoutPlayableItem(item.id)
            .presentationFor(item, expiredMembership),
        PlayerAccessPresentationState.lockedRecharge,
      );
    },
  );
}

PlayerFeedItem _lockedCoinItem() {
  const episode = PlayerEpisode(
    id: '8677',
    number: 8,
    isLocked: true,
    unlockType: EpisodeUnlockType.coins,
    requiredCoins: 2000,
  );
  const content = PlayerContent(
    id: '821',
    title: 'Test drama',
    playTitle: 'Test drama',
    synopsis: '',
    viewCountLabel: '',
    likeCountLabel: '',
    backgroundAssetPath: '',
    posterAssetPath: '',
    episodes: [episode],
    recommendations: [],
  );
  return const PlayerFeedItem(
    id: 'single:821:8677',
    mode: PlayerFeedMode.singleDrama,
    content: content,
    episode: episode,
  );
}
