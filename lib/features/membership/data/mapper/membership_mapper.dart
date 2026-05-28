import '../../domain/membership_plan.dart';
import '../dto/membership_benefit_dto.dart';
import '../dto/membership_data_dto.dart';
import '../dto/membership_product_dto.dart';

/// 会员远程 DTO 到 domain 的 mapper。
///
/// 会员商品列表和会员状态来自同一接口；mapper 只合成页面当前需要的展示快照，
/// 不在客户端推断真实会员权益。
class MembershipMapper {
  const MembershipMapper();

  MembershipData mapData(MembershipDataDto dto) {
    return MembershipData(
      isActive: dto.isMember,
      heroTitle: dto.heroTitle,
      heroSubtitle: dto.heroSubtitle,
      plans: dto.memberProducts.map(mapProduct).toList(growable: false),
      benefits: dto.benefits
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
      id: dto.productId.toString(),
      title: dto.productName,
      priceLabel: dto.priceText,
      dailyPriceLabel: _calculateDailyPrice(dto.priceText, dto.periodValue),
      period: _mapPeriodType(dto.periodType),
      platformProductId: dto.channelProductId,
      badgeLabel: dto.promotionText,
      originalPriceLabel: dto.originalPriceText,
      description: dto.productName,
      enabled: dto.status == 0, // 假设 status 0 表示可售
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

  /// 根据周期类型映射为字符串。
  /// 0=周/1=月/2=年
  String _mapPeriodType(int periodType) {
    switch (periodType) {
      case 0:
        return 'weekly';
      case 1:
        return 'monthly';
      case 2:
        return 'yearly';
      default:
        return 'monthly';
    }
  }

  /// 计算日均价格展示文案。
  String _calculateDailyPrice(String priceText, int periodValue) {
    if (periodValue <= 0) return '';
    // 简单处理：假设 priceText 是 "¥29.99" 这样的格式
    // 实际应该根据具体格式解析
    return priceText;
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
