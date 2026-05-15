import '../../domain/store_package.dart';
import '../dto/store_recharge_data_dto.dart';
import '../dto/store_recharge_product_dto.dart';

/// Store DTO 到 domain 的 mapper。
///
/// 价格 raw 字段会保留到 domain，UI 仍使用 localizedPrice；真实支付金额必须以订单接口
/// 和平台验单结果为准，不能让客户端用展示价自行结算。
class StoreMapper {
  const StoreMapper();

  StoreRechargeData mapRechargeData(StoreRechargeDataDto dto) {
    return StoreRechargeData(
      balance: dto.balance,
      coinPackages: dto.coinProducts.map(mapProduct).toList(growable: false),
      vipPackages: dto.vipProducts.map(mapProduct).toList(growable: false),
      tips: StoreTips(
        linksLabel: dto.linksLabel,
        subscriptionNote: dto.subscriptionNote,
        items: dto.tips,
      ),
    );
  }

  StorePackage mapProduct(StoreRechargeProductDto dto) {
    final kind = dto.kind.toLowerCase() == 'vip'
        ? StorePackageKind.vip
        : StorePackageKind.coins;
    return StorePackage(
      id: dto.productId,
      kind: kind,
      title: dto.title,
      priceLabel: dto.localizedPrice,
      baseCoins: dto.baseCoins,
      bonusCoins: dto.bonusCoins > 0
          ? dto.bonusCoins
          : (dto.totalCoins - dto.baseCoins).clamp(0, dto.totalCoins),
      priceMicros: dto.priceMicros,
      currencyCode: dto.currencyCode,
      originalPriceMicros: dto.originalPriceMicros,
      platformProductId: dto.platformProductId,
      basePlanId: dto.basePlanId,
      offerId: dto.offerId,
      productType: dto.productType,
      promotionId: dto.promotionId,
      promotionExpiresAt: dto.promotionExpiresAt,
      sortOrder: dto.sortOrder,
      enabled: dto.enabled,
      bonusLabel: dto.bonusCoins > 0 ? '+${dto.bonusCoins} Bonus' : null,
      badgeLabel: _badge(dto),
      originalPriceLabel: dto.localizedOriginalPrice,
      subtitle: dto.subtitle,
      footnote: dto.footnote,
      benefits: dto.benefits.map(_benefit).toList(growable: false),
    );
  }

  String? _badge(StoreRechargeProductDto dto) {
    if (dto.promotionId != null) return 'Limited offer';
    if (dto.bonusCoins <= 0 || dto.totalCoins <= 0) return null;
    final percent = (dto.bonusCoins / dto.totalCoins * 100).round();
    return '+$percent%';
  }

  StorePackageBenefit _benefit(StoreRechargeProductBenefitDto dto) {
    return StorePackageBenefit(icon: _benefitIcon(dto.icon), label: dto.label);
  }

  StoreBenefitIcon _benefitIcon(String value) {
    switch (value.toLowerCase()) {
      case 'download':
        return StoreBenefitIcon.download;
      case 'hd':
      case '1080p':
        return StoreBenefitIcon.hd;
      case 'points':
        return StoreBenefitIcon.points;
      case 'drama':
      default:
        return StoreBenefitIcon.drama;
    }
  }
}
