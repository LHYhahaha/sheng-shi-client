import 'package:drama_client/features/ad_unlock/domain/ad_unlock_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps exhausted sequential ad entry visible for limit feedback', () {
    const status = AdUnlockStatus(
      enabled: true,
      normalDailyLimit: 5,
      normalUsedCount: 5,
      normalRemainCount: 0,
      memberDailyLimit: 5,
      memberUsedCount: 0,
      memberRemainCount: 5,
      episodeUnlockStatus: AdEpisodeUnlockStatus.unlockable,
    );

    expect(status.canShowPrompt(AdUnlockDramaKind.normal), isFalse);
    expect(status.canShowPaywallAction(AdUnlockDramaKind.normal), isTrue);
    expect(status.hasRemaining(AdUnlockDramaKind.normal), isFalse);
  });
}
