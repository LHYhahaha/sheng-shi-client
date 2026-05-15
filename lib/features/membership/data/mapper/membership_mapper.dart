import '../../domain/membership_plan.dart';
import '../dto/membership_benefit_dto.dart';
import '../dto/membership_data_dto.dart';
import '../dto/membership_product_dto.dart';
import '../dto/membership_status_dto.dart';

/// 会员远程 DTO 到 domain 的 mapper。
///
/// 会员商品列表和会员状态未来可能来自不同接口；mapper 只合成页面当前需要的展示快照，
/// 不在客户端推断真实会员权益。
class MembershipMapper {
  const MembershipMapper();

  MembershipData mapData(MembershipDataDto dto) {
    final statusBenefits =
        dto.status?.benefits ?? const <MembershipBenefitDto>[];
    return MembershipData(
      isActive: dto.status?.isActive ?? false,
      heroTitle: dto.heroTitle,
      heroSubtitle: dto.heroSubtitle,
      plans: dto.products.map(mapProduct).toList(growable: false),
      benefits: (dto.benefits.isNotEmpty ? dto.benefits : statusBenefits)
          .map(mapBenefit)
          .toList(growable: false),
      tips: MembershipTips(
        subscriptionNote: dto.subscriptionNote,
        items: dto.tips,
      ),
    );
  }

  MembershipPlan mapProduct(MembershipProductDto dto) {
    return MembershipPlan(
      id: dto.productId,
      title: dto.title,
      priceLabel: dto.localizedPrice,
      dailyPriceLabel: dto.dailyPriceLabel ?? '',
      period: dto.period,
      platformProductId: dto.platformProductId,
      priceMicros: dto.priceMicros,
      currencyCode: dto.currencyCode,
      originalPriceMicros: dto.originalPriceMicros,
      promotionId: dto.promotionId,
      promotionExpiresAt: dto.promotionExpiresAt,
      enabled: dto.enabled,
      originalPriceLabel: dto.localizedOriginalPrice,
      badgeLabel: dto.promotionId == null ? null : 'Limited offer',
      description: dto.description,
    );
  }

  MembershipBenefit mapBenefit(MembershipBenefitDto dto) {
    return MembershipBenefit(
      icon: _icon(dto.icon),
      title: dto.title,
      highlight: dto.highlight,
      description: dto.description,
    );
  }

  MembershipData mapProductsAndStatus({
    required List<MembershipProductDto> products,
    required MembershipStatusDto status,
  }) {
    return MembershipData(
      isActive: status.isActive,
      heroTitle: 'Join Membership',
      heroSubtitle: status.isActive ? 'Membership active' : '',
      plans: products.map(mapProduct).toList(growable: false),
      benefits: status.benefits.map(mapBenefit).toList(growable: false),
      tips: const MembershipTips(subscriptionNote: '', items: []),
    );
  }

  MembershipBenefitIcon _icon(String value) {
    switch (value.toLowerCase()) {
      case 'download':
        return MembershipBenefitIcon.download;
      case 'points':
        return MembershipBenefitIcon.points;
      case 'members_only':
      case 'membersonly':
        return MembershipBenefitIcon.membersOnly;
      case 'hd':
      case '1080p':
        return MembershipBenefitIcon.hd;
      case 'ad_free':
      case 'adfree':
        return MembershipBenefitIcon.adFree;
      case 'series':
      default:
        return MembershipBenefitIcon.series;
    }
  }
}
