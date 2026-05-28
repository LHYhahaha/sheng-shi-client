/// 会员权益图标类型。
enum MembershipBenefitIcon { series, download, points, membersOnly, hd, adFree }

/// 会员套餐。
///
/// 价格相关字段都是展示 label，真实下单金额必须由服务端订单确认。
class MembershipPlan {
  const MembershipPlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.dailyPriceLabel,
    this.period,
    this.platformProductId,
    this.badgeLabel,
    this.originalPriceLabel,
    this.description,
    this.enabled = true,
  });

  /// 套餐 id（对应 productId）。
  ///
  /// 购买确认和服务端下单使用它，不能用标题/价格文案反查。
  final String id;

  /// 套餐标题（对应 productName）。
  final String title;

  /// 总价展示文案（对应 priceText）。
  final String priceLabel;

  /// 日均价展示文案。
  ///
  /// 只用于营销展示，不参与客户端金额计算。
  final String dailyPriceLabel;

  /// 订阅周期，如 weekly/monthly/yearly。
  final String? period;

  /// 渠道商品 id（对应 channelProductId）。
  final String? platformProductId;

  /// 徽标文案（对应 promotionText）。
  final String? badgeLabel;

  /// 原价展示文案（对应 originalPriceText）。
  final String? originalPriceLabel;

  /// 套餐描述。
  final String? description;

  /// 商品是否可售。
  final bool enabled;
}

/// 会员权益展示项。
class MembershipBenefit {
  const MembershipBenefit({
    required this.icon,
    required this.title,
    this.highlight,
    this.description,
  });

  /// 权益图标类型。
  final MembershipBenefitIcon icon;

  /// 权益标题。
  final String title;

  /// 高亮文案。
  final String? highlight;

  /// 权益说明。
  final String? description;
}

/// 会员页提示文案。
class MembershipTips {
  const MembershipTips({required this.subscriptionNote, required this.items});

  /// 订阅说明。
  final String subscriptionNote;

  /// 提示条目。
  final List<String> items;
}

/// 会员页聚合数据。
///
/// 这是权益状态、套餐和展示文案的同批快照。购买成功后应重新拉取它来确认权益。
class MembershipData {
  const MembershipData({
    required this.isActive,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.plans,
    required this.benefits,
    required this.tips,
  });

  /// 当前账号会员是否有效。
  final bool isActive;

  /// hero 主标题。
  final String heroTitle;

  /// hero 副标题。
  final String heroSubtitle;

  /// 可购买套餐列表。
  final List<MembershipPlan> plans;

  /// 权益展示列表。
  final List<MembershipBenefit> benefits;

  /// 提示文案。
  final MembershipTips tips;
}
