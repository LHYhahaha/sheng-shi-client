enum StorePackageKind { coins, vip }

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

  final String id;
  final StorePackageKind kind;
  final String title;
  final String priceLabel;
  final String? bonusLabel;
  final String? badgeLabel;
  final String? originalPriceLabel;
  final String? subtitle;
  final String? footnote;
  final List<StorePackageBenefit> benefits;

  bool get isCoinPackage => kind == StorePackageKind.coins;
}

class StorePackageBenefit {
  const StorePackageBenefit({required this.icon, required this.label});

  final StoreBenefitIcon icon;
  final String label;
}

enum StoreBenefitIcon { drama, download, hd, points }

class StoreRechargeData {
  const StoreRechargeData({
    required this.balance,
    required this.coinPackages,
    required this.vipPackages,
    required this.tips,
  });

  final int balance;
  final List<StorePackage> coinPackages;
  final List<StorePackage> vipPackages;
  final StoreTips tips;
}

class StoreTips {
  const StoreTips({
    required this.linksLabel,
    required this.subscriptionNote,
    required this.items,
  });

  final String linksLabel;
  final String subscriptionNote;
  final List<String> items;
}
