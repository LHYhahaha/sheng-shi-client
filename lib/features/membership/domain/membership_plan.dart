enum MembershipBenefitIcon { series, download, points, membersOnly, hd, adFree }

class MembershipPlan {
  const MembershipPlan({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.dailyPriceLabel,
    this.originalPriceLabel,
    this.badgeLabel,
    this.description,
  });

  final String id;
  final String title;
  final String priceLabel;
  final String dailyPriceLabel;
  final String? originalPriceLabel;
  final String? badgeLabel;
  final String? description;
}

class MembershipBenefit {
  const MembershipBenefit({
    required this.icon,
    required this.title,
    this.highlight,
    this.description,
  });

  final MembershipBenefitIcon icon;
  final String title;
  final String? highlight;
  final String? description;
}

class MembershipTips {
  const MembershipTips({required this.subscriptionNote, required this.items});

  final String subscriptionNote;
  final List<String> items;
}

class MembershipData {
  const MembershipData({
    required this.isActive,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.plans,
    required this.benefits,
    required this.tips,
  });

  final bool isActive;
  final String heroTitle;
  final String heroSubtitle;
  final List<MembershipPlan> plans;
  final List<MembershipBenefit> benefits;
  final MembershipTips tips;
}
