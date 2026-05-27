import '../../../shared/media/media_resource.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_summary.dart';

class MockProfileRepository implements ProfileRepository {
  const MockProfileRepository();

  @override
  Future<ProfileSummary> fetchProfileSummary() async {
    return const ProfileSummary(
      userId: '15589299',
      nickname: 'Guest',
      displayId: 'ID:15589299',
      avatarResource: sharedProfileAvatarResource,
      membership: ProfileMembershipSummary(isActive: false),
      wallet: ProfileWalletSummary(coinBalance: 2000, bonusBalance: 0),
      language: 'en',
      region: '',
    );
  }

  @override
  Future<Map<String, dynamic>> fetchWallet(int userId) async {
    return {
      'userId': userId,
      'coin': 2000,
      'bonusCoin': 0,
      'totalCoin': 2000,
    };
  }
}

const sharedProfileAvatarResource = MediaResource.asset(
  'assets/images/profile/profile_avatar_figma.png',
);
