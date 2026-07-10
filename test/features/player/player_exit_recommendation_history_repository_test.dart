import 'package:drama_client/features/player/data/shared_preferences_player_exit_recommendation_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores shown dramas per user key', () async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        SharedPreferencesPlayerExitRecommendationHistoryRepository();

    expect(
      await repository.hasShown(userKey: 'user:1', dramaId: 'drama-a'),
      isFalse,
    );

    await repository.markShown(userKey: 'user:1', dramaId: 'drama-a');

    expect(
      await repository.hasShown(userKey: 'user:1', dramaId: 'drama-a'),
      isTrue,
    );
    expect(
      await repository.hasShown(userKey: 'user:2', dramaId: 'drama-a'),
      isFalse,
    );
  });
}
