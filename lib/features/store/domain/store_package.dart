import '../../pay/domain/member_product_type.dart';

/// 商店套餐类型。
///
/// coins 和 vip 的购买后权益不同，不能只按卡片样式区分。
enum StorePackageKind { coins, vip }

/// 商店售卖套餐。
///
/// 这是充值页展示和确认弹窗共用模型。真实下单时应提交 id/kind，价格文案只用于展示，
/// 不作为客户端计算金额的来源。
class StorePackage {
  const StorePackage({
    required this.id,
    required this.kind,
    required this.title,
    required this.priceLabel,
    this.baseCoins = 0,
    this.bonusCoins = 0,
    this.priceMicros,
    this.currencyCode,
    this.originalPriceMicros,
    this.platformProductId,
    this.payChannel = 'PAY_CHANNEL_GOOGLE',
    this.memberType = '',
    this.periodIso,
    this.basePlanId,
    this.offerId,
    this.productType,
    this.promotionId,
    this.promotionExpiresAt,
    this.sortOrder,
    this.enabled = true,
    this.bonusLabel,
    this.badgeLabel,
    this.originalPriceLabel,
    this.subtitle,
    this.footnote,
    this.benefits = const [],
    this.promotionExpireSeconds = 0,
  });

  /// 套餐 id。
  ///
  /// 确认购买和服务端下单应使用它，不要用标题或价格文案匹配套餐。
  final String id;

  /// 套餐类型。
  ///
  /// 决定购买后是充值金币还是开通 VIP 权益。
  final StorePackageKind kind;

  /// 套餐主标题。
  final String title;

  /// 价格展示文案。
  ///
  /// 已格式化，不能作为客户端金额计算来源。真实金额应由服务端订单返回。
  final String priceLabel;

  /// 基础充值金币数。
  ///
  /// 仅金币包使用；真实接入后应该来自商品接口的结构化字段，而不是解析 title。
  final int baseCoins;

  /// 赠送金币数。
  ///
  /// 只用于展示校验。真实权益发放必须以后端验单/订单结果为准。
  final int bonusCoins;

  /// 原始价格微单位。
  ///
  /// 只做真实 API contract 预留；当前 UI 仍使用 priceLabel 展示。
  final int? priceMicros;

  /// 货币代码，例如 USD。
  final String? currencyCode;

  /// 原价微单位，只用于促销展示和订单校验，不参与客户端计费。
  final int? originalPriceMicros;

  /// Google/Apple 商品 id。
  ///
  /// 真实 IAP 下单使用平台商品 id，不要用展示标题反查。
  final String? platformProductId;

  /// 服务端支付渠道，用于决定是否需要查询平台商品价格。
  final String payChannel;

  /// 服务端会员商品类型；金币商品为空。
  final String memberType;

  /// Subscription period in ISO 8601 format, such as P1W / P1M / P3M / P1Y.
  final String? periodIso;

  /// Google Play base plan id。
  ///
  /// 订阅商品可能需要 base plan + offer 才能精确下单；金币消耗型商品通常为空。
  final String? basePlanId;

  /// Google Play / App Store 促销 offer id。
  final String? offerId;

  /// 平台商品类型，例如 consumable/subscription。
  ///
  /// 只做订单 contract 预留，不参与 UI 判断。
  final String? productType;

  /// 促销 id。
  final String? promotionId;

  /// 促销结束时间。
  final DateTime? promotionExpiresAt;

  /// 服务端排序值。
  final int? sortOrder;

  /// 商品是否可售。
  final bool enabled;

  /// 赠送或优惠展示文案。
  final String? bonusLabel;

  /// 徽标文案，例如推荐/热卖。
  final String? badgeLabel;

  /// 原价展示文案。
  ///
  /// 只用于视觉对比，不参与支付金额计算。
  final String? originalPriceLabel;

  /// 副标题说明。
  final String? subtitle;

  /// 脚注说明。
  final String? footnote;

  /// VIP 套餐权益展示列表。
  ///
  /// 只用于说明权益，真实权益以会员接口刷新为准。
  final List<StorePackageBenefit> benefits;

  /// 促销倒计时秒数。
  ///
  /// 仅会员商品，来自 API 的 `promotionExpireSeconds`。
  /// UI 层根据此字段计算倒计时结束时间。
  final int promotionExpireSeconds;

  bool get isCoinPackage => kind == StorePackageKind.coins;

  /// 仅订阅会员显示“自动续费，可随时取消”提示。
  bool get showsAutoRenewNotice =>
      !isCoinPackage &&
      MemberProductType.usesGoogleSubscriptionOffer(memberType);

  /// 套餐展示中的总金币数。
  ///
  /// 这里刻意保留结构化总数，避免 StoreController 去解析展示文案。真实阶段仍不能只信
  /// 客户端这个值，必须等服务端订单确认后再发放。
  int get totalCoins => baseCoins + bonusCoins;

  /// 创建套餐的副本，可选择性地覆盖字段。
  StorePackage copyWith({
    String? id,
    StorePackageKind? kind,
    String? title,
    String? priceLabel,
    int? baseCoins,
    int? bonusCoins,
    int? priceMicros,
    String? currencyCode,
    int? originalPriceMicros,
    String? platformProductId,
    String? payChannel,
    String? memberType,
    String? periodIso,
    String? basePlanId,
    String? offerId,
    String? productType,
    String? promotionId,
    DateTime? promotionExpiresAt,
    int? sortOrder,
    bool? enabled,
    String? bonusLabel,
    String? badgeLabel,
    String? originalPriceLabel,
    String? subtitle,
    String? footnote,
    List<StorePackageBenefit>? benefits,
    int? promotionExpireSeconds,
  }) {
    return StorePackage(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      priceLabel: priceLabel ?? this.priceLabel,
      baseCoins: baseCoins ?? this.baseCoins,
      bonusCoins: bonusCoins ?? this.bonusCoins,
      priceMicros: priceMicros ?? this.priceMicros,
      currencyCode: currencyCode ?? this.currencyCode,
      originalPriceMicros: originalPriceMicros ?? this.originalPriceMicros,
      platformProductId: platformProductId ?? this.platformProductId,
      payChannel: payChannel ?? this.payChannel,
      memberType: memberType ?? this.memberType,
      periodIso: periodIso ?? this.periodIso,
      basePlanId: basePlanId ?? this.basePlanId,
      offerId: offerId ?? this.offerId,
      productType: productType ?? this.productType,
      promotionId: promotionId ?? this.promotionId,
      promotionExpiresAt: promotionExpiresAt ?? this.promotionExpiresAt,
      sortOrder: sortOrder ?? this.sortOrder,
      enabled: enabled ?? this.enabled,
      bonusLabel: bonusLabel ?? this.bonusLabel,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      originalPriceLabel: originalPriceLabel ?? this.originalPriceLabel,
      subtitle: subtitle ?? this.subtitle,
      footnote: footnote ?? this.footnote,
      benefits: benefits ?? this.benefits,
      promotionExpireSeconds:
          promotionExpireSeconds ?? this.promotionExpireSeconds,
    );
  }
}

/// 商店套餐权益展示项。
class StorePackageBenefit {
  const StorePackageBenefit({required this.icon});

  /// 展示图标类型。
  final StoreBenefitIcon icon;
}

/// 商店权益图标类型。
enum StoreBenefitIcon { drama, download, hd, points }

/// 充值页聚合数据。
///
/// 余额、金币包、VIP 包和提示文案同批返回，保证页面初始选择和展示一致。
class StoreRechargeData {
  const StoreRechargeData({
    required this.balance,
    required this.coinPackages,
    required this.vipPackages,
    required this.tips,
  });

  /// 当前金币余额展示值。
  final int balance;

  /// 金币充值套餐。
  final List<StorePackage> coinPackages;

  /// VIP 售卖套餐。
  final List<StorePackage> vipPackages;

  /// 商店提示文案。
  final StoreTips tips;
}

/// 商店提示文案。
///
/// 当前用于模拟订阅说明和协议入口；真实支付条款仍应以支付页/服务端配置为准。
class StoreTips {
  const StoreTips({
    required this.linksLabel,
    required this.subscriptionNote,
    required this.items,
  });

  /// 协议链接区域文案。
  final String linksLabel;

  /// 订阅或购买说明。
  final String subscriptionNote;

  /// 提示条目列表。
  final List<String> items;
}
