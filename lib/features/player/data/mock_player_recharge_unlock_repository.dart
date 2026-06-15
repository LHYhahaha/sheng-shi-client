import '../data/dto/player_episode_unlock_dto.dart';
import '../domain/player_recharge_unlock_offer.dart';
import '../domain/player_recharge_unlock_repository.dart';

/// 解锁充值弹窗的 mock 数据源。
///
/// mock 数据刻意覆盖有赠币/无赠币、促销/非促销、多行 tips 和多权益，方便第一期 UI
/// 接近真实商品结构。真实接入时替换 repository，不要把这些商品写进 widget。
class MockPlayerRechargeUnlockRepository
    implements PlayerRechargeUnlockRepository {
  const MockPlayerRechargeUnlockRepository();

  @override
  Future<PlayerRechargeUnlockOffer> fetchOffer({
    required String itemId,
    required int requiredCoins,
    bool isMember = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return PlayerRechargeUnlockOffer(
      requiredCoins: requiredCoins,
      coinPackages: const [
        PlayerRechargeCoinPackage(
          id: 'coins_100',
          baseCoins: 100,
          bonusCoins: 0,
          googleProductId: 'coins_100',
          googlePriceLabel: r'$0.99',
        ),
        PlayerRechargeCoinPackage(
          id: 'coins_300',
          baseCoins: 300,
          bonusCoins: 30,
          googleProductId: 'coins_300_bonus',
          googlePriceLabel: r'$2.99',
        ),
        PlayerRechargeCoinPackage(
          id: 'coins_700',
          baseCoins: 700,
          bonusCoins: 100,
          googleProductId: 'coins_700_bonus',
          googlePriceLabel: r'$6.99',
        ),
        PlayerRechargeCoinPackage(
          id: 'coins_1500',
          baseCoins: 1500,
          bonusCoins: 300,
          googleProductId: 'coins_1500_bonus',
          googlePriceLabel: r'$14.99',
        ),
      ],
      // 如果用户已是会员，不返回会员商品
      membershipPackages: isMember
          ? []
          : const [
              PlayerRechargeMembershipPackage(
                id: 'weekly_vip_promo',
                periodLabel: 'Weekly',
                googleProductId: 'vip_weekly_intro',
                googlePriceLabel: r'$12.99',
                originalPriceLabel: r'$24.99',
                isPromotional: true,
                description: 'Auto renew\nCancel anytime',
              ),
              PlayerRechargeMembershipPackage(
                id: 'monthly_vip',
                periodLabel: 'Monthly',
                googleProductId: 'vip_monthly',
                googlePriceLabel: r'$29.99',
              ),
            ],
      benefits: const [
        PlayerRechargeBenefit(
          icon: PlayerRechargeBenefitIcon.series,
          label: 'Unlock 8,000+ dramas',
        ),
        PlayerRechargeBenefit(
          icon: PlayerRechargeBenefitIcon.download,
          label: 'Download episodes',
        ),
        PlayerRechargeBenefit(
          icon: PlayerRechargeBenefitIcon.hd,
          label: '1080p quality',
        ),
        PlayerRechargeBenefit(
          icon: PlayerRechargeBenefitIcon.points,
          label: 'Daily member points',
        ),
      ],
      tips:
          'Coins are used to unlock paid episodes.\nVIP membership unlocks eligible dramas during the active period.',
    );
  }

  @override
  Future<PlayerEpisodeUnlockDto> unlockEpisodeWithCoin({
    required bool autoUnlockNext,
    required int coin,
    required int dramaId,
    required int episodeNo,
    required String shortTitle,
    String? cover,
    int? episodeId,
  }) async {
    // Mock 延迟
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Mock 成功返回
    return PlayerEpisodeUnlockDto(
      autoUnlock: autoUnlockNext,
      bonusCoin: 0,
      coin: 1000, // 假设用户当前有1000金币
      costCoin: coin,
      dramaId: dramaId,
      episodeId: episodeId ?? 0,
      success: true,
      userId: 12345,
    );
  }
}
