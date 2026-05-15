import '../../../../shared/media/media_resource.dart';
import '../../domain/profile_summary.dart';
import '../dto/profile_summary_dto.dart';

class ProfileMapper {
  const ProfileMapper();

  ProfileSummary mapSummary(ProfileSummaryDto dto) {
    return ProfileSummary(
      userId: dto.userId,
      nickname: dto.nickname,
      displayId: dto.displayId,
      avatarResource: dto.avatarUrl == null
          ? const MediaResource.asset(
              'assets/images/profile/profile_avatar_figma.png',
            )
          : MediaResource.network(dto.avatarUrl!),
      membership: ProfileMembershipSummary(
        isActive: dto.membershipSummary.isActive,
        planId: dto.membershipSummary.planId,
        expiresAt: dto.membershipSummary.expiresAt,
      ),
      wallet: ProfileWalletSummary(
        coinBalance: dto.walletSummary.coinBalance,
        bonusBalance: dto.walletSummary.bonusBalance,
      ),
      language: dto.language,
      region: dto.region,
      createdAt: dto.createdAt,
    );
  }
}
