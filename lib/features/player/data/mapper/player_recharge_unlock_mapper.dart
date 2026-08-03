import 'package:flutter/foundation.dart';

import '../../../../features/pay/domain/iap_product_info.dart';
import '../../../../features/pay/domain/pay_channel.dart';
import '../../../../features/store/data/dto/coin_product_dto.dart';
import '../../../../features/store/data/dto/member_product_dto.dart';
import '../../domain/player_recharge_unlock_offer.dart';

/// Player 充值解锁弹窗的 Mapper。
///
/// 将 Store 模块的 DTO 映射为 Player 专用的展示模型。
/// IAP 价格（含促销价、原价、offerToken）通过 [IapProductInfo] 一次性组装，
/// 避免在各层重复查询或提取促销信息。
class PlayerRechargeUnlockMapper {
  const PlayerRechargeUnlockMapper._();

  static PlayerRechargeUnlockOffer mapToOffer(
    dynamic dto,
    Map<String, IapProductInfo> iapDetails,
    int requiredCoins, {
    bool isMember = false,
  }) {
    final coinProducts = dto.coinProducts as List<dynamic>;
    final memberProducts = dto.memberProducts as List<dynamic>;

    return PlayerRechargeUnlockOffer(
      requiredCoins: requiredCoins,
      coinPackages: coinProducts
          .where((p) => _isVisible(p as CoinProductDto, iapDetails))
          .map((p) => mapCoinProduct(p as CoinProductDto, iapDetails))
          .toList(),
      // 如果用户已是会员，不返回会员商品
      membershipPackages: isMember
          ? []
          : memberProducts
                .where((p) => _isVisible(p as MemberProductDto, iapDetails))
                .map((p) => mapMemberProduct(p as MemberProductDto, iapDetails))
                .toList(),
      benefits: _defaultBenefits(),
      tips:
          'Coins are used to unlock paid episodes.\nVIP membership unlocks eligible dramas during the active period.',
    );
  }

  static PlayerRechargeCoinPackage mapCoinProduct(
    CoinProductDto dto,
    Map<String, IapProductInfo> iapDetails,
  ) {
    final baseCoins = int.tryParse(dto.coin) ?? 0;
    final bonusCoins = int.tryParse(dto.bonusCoin) ?? 0;

    final iapInfo = iapDetails[dto.channelProductId];

    return PlayerRechargeCoinPackage(
      id: dto.productId,
      baseCoins: baseCoins,
      bonusCoins: bonusCoins,
      googleProductId: dto.channelProductId,
      googlePriceLabel:
          iapInfo?.displayPrice ??
          _serverPriceLabel(dto.currencySymbol, dto.priceText),
      iapInfo: iapInfo,
    );
  }

  static PlayerRechargeMembershipPackage mapMemberProduct(
    MemberProductDto dto,
    Map<String, IapProductInfo> iapDetails,
  ) {
    final iapInfo = iapDetails[dto.channelProductId];

    final backendPromotionExpireSeconds = dto.promotionExpireSeconds ?? 0;
    final hasIapPromo = iapInfo?.hasPromo == true;
    final promotionExpireSeconds = hasIapPromo
        ? backendPromotionExpireSeconds > 0
              ? backendPromotionExpireSeconds
              : 3600
        : 0;

    return PlayerRechargeMembershipPackage(
      id: dto.productId,
      periodLabel: _periodLabel(dto.periodType, dto.periodValue),
      googleProductId: dto.channelProductId,
      googlePriceLabel:
          iapInfo?.displayPrice ??
          _serverPriceLabel(dto.currencySymbol, dto.priceText),
      periodIso: _periodIso(dto.periodType, dto.periodValue),
      originalPriceLabel: iapInfo?.displayOriginalPrice,
      isPromotional: hasIapPromo,
      description: hasIapPromo ? dto.promotionText : null,
      promotionExpireSeconds: promotionExpireSeconds,
      basePlanId: iapInfo?.basePlanId,
      offerId: iapInfo?.offerId,
      iapInfo: iapInfo,
    );
  }

  static String _periodLabel(String periodType, int periodValue) {
    switch (periodType) {
      case 'MEMBER_PERIOD_TYPE_DAY':
        return periodValue == 1 ? '1 Day' : '$periodValue Days';
      case 'MEMBER_PERIOD_TYPE_WEEK':
        return periodValue == 1 ? '1 Week' : '$periodValue Weeks';
      case 'MEMBER_PERIOD_TYPE_MONTH':
        return periodValue == 1 ? '1 Month' : '$periodValue Months';
      case 'MEMBER_PERIOD_TYPE_YEAR':
        return periodValue == 1 ? '1 Year' : '$periodValue Years';
      default:
        return 'Unknown';
    }
  }

  static String? _periodIso(String periodType, int periodValue) {
    if (periodValue <= 0) return null;
    return switch (periodType) {
      'MEMBER_PERIOD_TYPE_DAY' => 'P${periodValue}D',
      'MEMBER_PERIOD_TYPE_WEEK' => 'P${periodValue}W',
      'MEMBER_PERIOD_TYPE_MONTH' => 'P${periodValue}M',
      'MEMBER_PERIOD_TYPE_YEAR' => 'P${periodValue}Y',
      _ => null,
    };
  }

  static bool _isVisible(
    dynamic product,
    Map<String, IapProductInfo> iapDetails,
  ) {
    final payChannel = product.payChannel as String;
    final channelProductId = product.channelProductId as String;
    return PayChannel.isOther(payChannel) ||
        (PayChannel.isApple(payChannel) &&
            defaultTargetPlatform == TargetPlatform.iOS) ||
        (PayChannel.isGoogle(payChannel) &&
            iapDetails.containsKey(channelProductId));
  }

  static String _serverPriceLabel(String currencySymbol, String priceText) =>
      '$currencySymbol$priceText';

  static List<PlayerRechargeBenefit> _defaultBenefits() {
    return const [
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
    ];
  }
}
