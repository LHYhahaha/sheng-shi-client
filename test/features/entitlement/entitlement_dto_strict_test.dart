import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/entitlement/data/dto/episode_access_decision_dto.dart';
import 'package:drama_client/features/entitlement/data/dto/user_entitlement_state_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing decision type throws', () {
    expect(
      () => EpisodeAccessDecisionDto.fromJson({
        'dramaId': 'drama',
        'episodeId': 'ep',
        'itemId': 'item',
        'unlockType': 'coins',
        'price': 30,
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('unknown decision type throws', () {
    expect(
      () => EpisodeAccessDecisionDto.fromJson({
        'type': 'mystery',
        'dramaId': 'drama',
        'episodeId': 'ep',
        'itemId': 'item',
        'unlockType': 'coins',
        'price': 30,
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('coin unlock without price throws', () {
    expect(
      () => EpisodeAccessDecisionDto.fromJson({
        'type': 'showCoinUnlockDialog',
        'dramaId': 'drama',
        'episodeId': 'ep',
        'itemId': 'item',
        'unlockType': 'coins',
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('coinBalance wrong type throws', () {
    expect(
      () => UserEntitlementStateDto.fromJson({
        'isGuest': false,
        'isMember': true,
        'coinBalance': 'oops',
        'bonusBalance': 0,
        'autoUnlockEnabled': true,
        'unlockedEpisodeIds': [],
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });
}
