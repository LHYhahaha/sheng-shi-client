/// 未解锁剧集的充值/会员组合弹窗数据。
///
/// 这是 entitlement unlock flow 的展示模型，不是普通 Store 页面模型。它只描述当前
/// “继续解锁这一集”需要展示哪些充值/会员选择；真实支付、验单和权益发放仍必须走
/// 服务端订单与 entitlement 接口。
class PlayerRechargeUnlockOffer {
  const PlayerRechargeUnlockOffer({
    required this.requiredCoins,
    required this.coinPackages,
    required this.membershipPackages,
    required this.benefits,
    required this.tips,
  });

  /// 当前剧集解锁需要的金币数。
  final int requiredCoins;

  /// 金币充值档位。
  ///
  /// 价格使用 mock Google product price label，避免 UI 写死渠道价格格式。
  final List<PlayerRechargeCoinPackage> coinPackages;

  /// 会员订阅档位。
  ///
  /// 这里只用于弹窗营销展示；购买成功后是否会员生效仍要服务端验单。
  final List<PlayerRechargeMembershipPackage> membershipPackages;

  /// 会员权益。
  ///
  /// 每行最多展示两个，由 UI 层按列表顺序排版。
  final List<PlayerRechargeBenefit> benefits;

  /// 解锁/充值说明文案。
  ///
  /// 由 mock 服务端配置下发，支持换行。UI 不解析其中内容做业务判断。
  final String tips;
}

/// 金币充值档位。
class PlayerRechargeCoinPackage {
  const PlayerRechargeCoinPackage({
    required this.id,
    required this.baseCoins,
    required this.bonusCoins,
    required this.googleProductId,
    required this.googlePriceLabel,
  });

  final String id;
  final int baseCoins;
  final int bonusCoins;

  /// mock Google 商品 id。
  ///
  /// 真实接入时用它和 Google Billing ProductDetails 对齐，不能用 UI title 下单。
  final String googleProductId;

  /// mock Google 商品价格展示。
  ///
  /// 价格格式由渠道商品返回，UI 不应自行拼币种。
  final String googlePriceLabel;

  int get totalCoins => baseCoins + bonusCoins;

  /// bonus 角标百分比。
  ///
  /// 需求要求使用 bonus / (base + bonus) 计算，而不是 bonus / base。无赠币时不展示。
  int get bonusPercent {
    if (bonusCoins <= 0 || totalCoins <= 0) {
      return 0;
    }
    return (bonusCoins / totalCoins * 100).round();
  }

  bool get hasBonus => bonusCoins > 0;
}

/// 会员订阅档位。
class PlayerRechargeMembershipPackage {
  const PlayerRechargeMembershipPackage({
    required this.id,
    required this.periodLabel,
    required this.googleProductId,
    required this.googlePriceLabel,
    this.originalPriceLabel,
    this.isPromotional = false,
    this.description,
  });

  final String id;
  final String periodLabel;
  final String googleProductId;
  final String googlePriceLabel;
  final String? originalPriceLabel;
  final bool isPromotional;

  /// 后台 mock 下发简介。
  ///
  /// 为空时 UI 使用默认 “Auto renew · Cancel anytime”。真实接入后仍只作为展示文案。
  final String? description;

  String get title => '$periodLabel VIP';
}

/// 会员权益展示项。
class PlayerRechargeBenefit {
  const PlayerRechargeBenefit({required this.icon, required this.label});

  final PlayerRechargeBenefitIcon icon;
  final String label;
}

/// 权益 icon 语义。
///
/// domain 层不依赖 Flutter IconData，避免业务模型和 Material UI 绑定。
enum PlayerRechargeBenefitIcon { series, download, hd, points, noAds }
