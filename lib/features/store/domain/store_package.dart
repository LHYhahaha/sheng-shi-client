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
    this.bonusLabel,
    this.badgeLabel,
    this.originalPriceLabel,
    this.subtitle,
    this.footnote,
    this.benefits = const [],
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

  bool get isCoinPackage => kind == StorePackageKind.coins;
}

/// 商店套餐权益展示项。
class StorePackageBenefit {
  const StorePackageBenefit({required this.icon, required this.label});

  /// 展示图标类型。
  final StoreBenefitIcon icon;

  /// 权益文案。
  final String label;
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
