import '../../domain/membership_plan.dart';
import '../../../../core/utils/period_iso_parser.dart';
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
    );
  }

  MembershipPlan mapProduct(MembershipProductDto dto) {
    final priceLabel = dto.iapPriceText ?? dto.priceText;
    final hasIapPromo = dto.iapHasPromo == true;
    final originalPriceLabel = hasIapPromo ? dto.iapRegularPriceText : null;

    return MembershipPlan(
      id: dto.productId.toString(),
      title: dto.productName,
      priceLabel: priceLabel,
      dailyPriceLabel: _calculateDailyPrice(dto.periodValue),
      period: _mapPeriodIso(dto.iapPromoPeriod ?? dto.iapRegularPeriod),
      platformProductId: dto.channelProductId,
      badgeLabel: null,
      originalPriceLabel: originalPriceLabel,
      promotionPriceLabel: dto.iapPriceText,
      hasPromo: hasIapPromo,
      regularPriceLabel: hasIapPromo ? dto.iapRegularPriceText : null,
      promoCountdownEndMs: hasIapPromo
          ? _calcCountdownEndMs(dto.promotionExpireSeconds)
          : 0,
      description: dto.productName,
      enabled: dto.status == 0,
      promoPeriodIso: hasIapPromo ? dto.iapPromoPeriod : null,
      regularPeriodIso: dto.iapRegularPeriod,
    );
  }

  String? _mapPeriodIso(String? iso) {
    if (iso == null) return null;
    return PeriodIsoParser.toDisplayLabel(iso);
  }

  // ── 日均价计算 ─────────────────────────────────────

  String _calculateDailyPrice(int periodValue) {
    if (periodValue <= 0) return '';
    return '';
  }

  // ── 倒计时计算 ─────────────────────────────────────

  int _calcCountdownEndMs(int? promotionExpireSeconds) {
    final seconds = promotionExpireSeconds ?? 3600;
    if (seconds <= 0) return 0;
    return DateTime.now().millisecondsSinceEpoch + seconds * 1000;
  }
}
