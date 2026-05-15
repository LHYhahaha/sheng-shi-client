import '../../../shared/media/media_resource.dart';

class ProfileMembershipSummary {
  const ProfileMembershipSummary({
    required this.isActive,
    this.planId,
    this.expiresAt,
  });

  final bool isActive;
  final String? planId;
  final DateTime? expiresAt;
}

class ProfileWalletSummary {
  const ProfileWalletSummary({
    required this.coinBalance,
    required this.bonusBalance,
  });

  final int coinBalance;
  final int bonusBalance;
}

/// 我的页远程摘要模型。
///
/// 它是未来 Profile API 的聚合结果，不替代 Auth/Entitlement/Wallet 的真实来源。
/// 当前 ProfilePage 仍由 AuthState + ProfileController mock 合成，本模型只作为 API
/// skeleton contract。
class ProfileSummary {
  const ProfileSummary({
    required this.userId,
    required this.nickname,
    required this.displayId,
    required this.avatarResource,
    required this.membership,
    required this.wallet,
    required this.language,
    required this.region,
    this.createdAt,
  });

  final String userId;
  final String nickname;
  final String displayId;
  final MediaResource avatarResource;
  final ProfileMembershipSummary membership;
  final ProfileWalletSummary wallet;
  final String language;
  final String region;
  final DateTime? createdAt;
}
