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
    this.payChannel = 'PAY_CHANNEL_GOOGLE',
    this.memberType = '',
    this.badgeLabel,
    this.originalPriceLabel,

    /// 促销价展示文案（Google IAP 促销首期价）。
    ///
    /// 当 [hasPromo] 为 true 时，[priceLabel] 可能已被更新为促销价。
    /// 这个字段用于 UI 明确展示促销价格。
    this.promotionPriceLabel,

    /// 是否有促销价。
    this.hasPromo = false,

    /// 续费原价展示文案（促销结束后的价格）。
    this.regularPriceLabel,

    /// 促销倒计时截止时间（毫秒时间戳），0 表示无倒计时。
    ///
    /// UI 层根据此字段展示倒计时，倒计时结束后隐藏促销标签。
    this.promoCountdownEndMs = 0,
    this.description,
    this.enabled = true,

    /// Google Play IAP 促销首期周期 ISO，如 "P1W"。
    ///
    /// 用于 UI 层根据当前语言动态组装促销文案。
    this.promoPeriodIso,
    this.promoCycles,
    this.hasFreeTrial = false,

    /// Google Play IAP 续费周期 ISO，如 "P1M"。
    ///
    /// 用于 UI 层根据当前语言动态组装促销文案。
    this.regularPeriodIso,
  });

  /// 套餐 id（对应 productId）。
  ///
  /// 购买确认和服务端下单使用它，不能用标题/价格文案反查。
  final String id;

  /// 套餐标题（对应 productName）。
  final String title;

  /// 总价展示文案（对应 priceText）。
  ///
  /// 当存在促销时，此字段可能是促销首期价。
  final String priceLabel;

  /// 日均价展示文案。
  ///
  /// 只用于营销展示，不参与客户端金额计算。
  final String dailyPriceLabel;

  /// 订阅周期 ISO 8601 格式，如 P1W / P1M / P1Y。
  final String? period;

  /// 渠道商品 id（对应 channelProductId）。
  final String? platformProductId;

  /// 服务端支付渠道，用于决定是否需要查询平台商品价格。
  final String payChannel;

  /// 服务端会员商品类型，决定埋点分类和订阅 offer 的购买参数。
  final String memberType;

  /// 徽标文案（对应 promotionText）。
  final String? badgeLabel;

  /// 原价展示文案（对应 originalPriceText）。
  final String? originalPriceLabel;

  /// 促销价展示文案（Google IAP 促销首期价）。
  final String? promotionPriceLabel;

  /// 是否有促销价。
  final bool hasPromo;

  /// 续费原价展示文案（促销结束后的价格）。
  final String? regularPriceLabel;

  /// 促销倒计时截止时间（毫秒时间戳），0 表示无倒计时。
  ///
  /// UI 层根据此字段展示倒计时，倒计时结束后隐藏促销标签。
  final int promoCountdownEndMs;

  /// 套餐描述。
  final String? description;

  /// 商品是否可售。
  final bool enabled;

  /// Google Play IAP 促销首期周期 ISO，如 "P1W"。
  ///
  /// 用于 UI 层根据当前语言动态组装促销文案。
  final String? promoPeriodIso;

  /// Google Play IAP 促销周期的执行次数，例如 2 表示连续两个 P1W 周期。
  final int? promoCycles;

  /// 促销首期是否为免费试用。
  final bool hasFreeTrial;

  /// Google Play IAP 续费周期 ISO，如 "P1M"。
  ///
  /// 用于 UI 层根据当前语言动态组装促销文案。
  final String? regularPeriodIso;
}

/// 会员权益展示项。
class MembershipBenefit {
  const MembershipBenefit({
    required this.iconPath,
    required this.title,
    this.highlight,
    this.description,
  });

  /// 权益图标本地图片路径。
  final String iconPath;

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
  });

  /// 当前账号会员是否有效。
  final bool isActive;

  /// hero 主标题。
  final String heroTitle;

  /// hero 副标题。
  final String heroSubtitle;

  /// 可购买套餐列表。
  final List<MembershipPlan> plans;
}
