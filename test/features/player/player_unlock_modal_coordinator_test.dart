import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
import 'package:drama_client/features/player/application/player_unlock_modal_coordinator.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('membership episode always opens the vip-only recharge flow', () {
    final item = _item(unlockType: EpisodeUnlockType.membership);

    expect(rechargeVipOnlyForItem(item, requestedVipOnly: false), isTrue);
  });

  test('coin episode keeps the requested recharge flow type', () {
    final item = _item(unlockType: EpisodeUnlockType.coins);

    expect(rechargeVipOnlyForItem(item, requestedVipOnly: false), isFalse);
  });
}

PlayerFeedItem _item({required EpisodeUnlockType unlockType}) {
  final episode = PlayerEpisode(
    id: 'episode-1',
    number: 1,
    isLocked: true,
    unlockType: unlockType,
  );
  return PlayerFeedItem(
    id: 'item-1',
    mode: PlayerFeedMode.singleDrama,
    content: PlayerContent(
      id: 'drama-1',
      title: 'Drama',
      playTitle: 'Drama',
      synopsis: '',
      viewCountLabel: '',
      likeCountLabel: '',
      backgroundAssetPath: '',
      posterAssetPath: '',
      episodes: [episode],
      recommendations: const [],
    ),
    episode: episode,
  );
}
