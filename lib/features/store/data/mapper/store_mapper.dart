import '../../domain/store_package.dart';
import '../dto/coin_product_dto.dart';
import '../dto/member_product_dto.dart';
import '../dto/store_recharge_data_dto.dart';

/// Store DTO 到 domain 的 mapper。
///
/// 价格 raw 字段会保留到 domain，UI 仍使用 priceText；真实支付金额必须以订单接口
/// 和平台验单结果为准，不能让客户端用展示价自行结算。
class StoreMapper {
  const StoreMapper();

  StoreRechargeData mapRechargeData(StoreRechargeDataDto dto) {
    return StoreRechargeData(
      balance: dto.balance,
      coinPackages: dto.coinProducts
          .map(mapCoinProduct)
          .toList(growable: false),
      vipPackages: dto.memberProducts
          .map(mapMemberProduct)
          .toList(growable: false),
      tips: const StoreTips(
        linksLabel: 'Terms & Restore',
        subscriptionNote:
            'Subscription will auto-renew. Cancel anytime in Google Play.',
        items: [
          'Coins can be used to unlock dramas',
          'VIP membership is auto-renewable',
          'Prices may vary by region',
        ],
      ),
    );
  }

  StorePackage mapCoinProduct(CoinProductDto dto) {
    final baseCoins = int.tryParse(dto.coin) ?? 0;
    final bonusCoins = int.tryParse(dto.bonusCoin) ?? 0;

    return StorePackage(
      id: dto.productId,
      kind: StorePackageKind.coins,
      title: dto.productName?.isNotEmpty == true
          ? dto.productName!
          : '${dto.coin} Coins',
      priceLabel: dto.priceText, // API返回的展示价格
      baseCoins: baseCoins,
      bonusCoins: bonusCoins,
      platformProductId: dto.channelProductId, // 用于IAP查询和购买
      productType: 'consumable',
      sortOrder: dto.sort,
      enabled: dto.status == 1,
      bonusLabel: bonusCoins > 0 ? '+$bonusCoins Bonus' : null,
      badgeLabel: _badgeForCoin(bonusCoins, baseCoins), // 优惠比例角标
    );
  }

  StorePackage mapMemberProduct(MemberProductDto dto) {
    return StorePackage(
      id: dto.productId,
      kind: StorePackageKind.vip,
      title: dto.productName?.isNotEmpty == true
          ? dto.productName!
          : _defaultTitleForPeriod(dto.periodType, dto.periodValue),
      priceLabel: dto.priceText, // API返回的展示价格
      baseCoins: 0,
      bonusCoins: 0,
      platformProductId: dto.channelProductId, // 用于IAP查询和购买
      productType: 'subscription',
      sortOrder: dto.sort,
      enabled: dto.status == 1,
      originalPriceLabel: null,
      subtitle: null,
      badgeLabel: null,
      promotionExpireSeconds: 0,
      benefits: _defaultBenefits(),
    );
  }

  String? _badgeForCoin(int bonusCoins, int baseCoins) {
    if (bonusCoins <= 0 || baseCoins <= 0) return null;
    // 优惠比例 = 赠送数量 / 基础金币数量 * 100%，向下取整
    final percent = (bonusCoins / baseCoins * 100).floor();
    if (percent <= 0) return null;
    return '+$percent%';
  }

  String _defaultTitleForPeriod(String periodType, int periodValue) {
    switch (periodType) {
      case 'MEMBER_PERIOD_TYPE_DAY':
        return periodValue == 1 ? '1 Day VIP' : '$periodValue Days VIP';
      case 'MEMBER_PERIOD_TYPE_WEEK':
        return periodValue == 1 ? '1 Week VIP' : '$periodValue Weeks VIP';
      case 'MEMBER_PERIOD_TYPE_MONTH':
        return periodValue == 1 ? '1 Month VIP' : '$periodValue Months VIP';
      case 'MEMBER_PERIOD_TYPE_YEAR':
        return periodValue == 1 ? '1 Year VIP' : '$periodValue Years VIP';
      default:
        return 'VIP Membership';
    }
  }

  List<StorePackageBenefit> _defaultBenefits() {
    return const [
      StorePackageBenefit(
        icon: StoreBenefitIcon.drama,
        label: 'Unlimited dramas',
      ),
      StorePackageBenefit(
        icon: StoreBenefitIcon.download,
        label: 'Download offline',
      ),
      StorePackageBenefit(icon: StoreBenefitIcon.hd, label: 'HD quality'),
      StorePackageBenefit(
        icon: StoreBenefitIcon.points,
        label: 'Exclusive points',
      ),
    ];
  }
}
