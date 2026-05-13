import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

class ProfileState {
  const ProfileState({
    required this.isLoggedIn,
    required this.userId,
    required this.nickname,
    required this.avatarAssetPath,
    required this.membership,
    required this.coins,
    required this.language,
  });

  const ProfileState.mock()
    : isLoggedIn = false,
      userId = '15589299',
      nickname = null,
      avatarAssetPath = 'assets/images/profile/profile_avatar_figma.png',
      membership = const ProfileMembershipState.mock(),
      coins = const ProfileCoinsState.mock(),
      language = const ProfileLanguageState.enabled();

  final bool isLoggedIn;
  final String userId;
  final String? nickname;
  final String avatarAssetPath;
  final ProfileMembershipState membership;
  final ProfileCoinsState coins;
  final ProfileLanguageState language;

  bool get canOpenMembership => membership.entryEnabled;

  bool get canOpenTopUp => coins.topUpEnabled;

  bool get canOpenLanguage => language.entryEnabled;

  ProfileState copyWith({
    bool? isLoggedIn,
    String? userId,
    String? nickname,
    String? avatarAssetPath,
  }) {
    return ProfileState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      nickname: nickname,
      avatarAssetPath: avatarAssetPath ?? this.avatarAssetPath,
      membership: membership,
      coins: coins,
      language: language,
    );
  }
}

class ProfileMembershipState {
  const ProfileMembershipState({
    required this.isActive,
    required this.entryEnabled,
    this.expiresAt,
  });

  const ProfileMembershipState.mock()
    : isActive = false,
      entryEnabled = true,
      expiresAt = null;

  final bool isActive;
  final bool entryEnabled;
  final DateTime? expiresAt;
}

class ProfileCoinsState {
  const ProfileCoinsState({
    required this.balance,
    required this.topUpEnabled,
    required this.walletEnabled,
  });

  const ProfileCoinsState.mock()
    : balance = 2000,
      topUpEnabled = true,
      walletEnabled = true;

  final int balance;
  final bool topUpEnabled;
  final bool walletEnabled;
}

class ProfileLanguageState {
  const ProfileLanguageState({required this.entryEnabled});

  const ProfileLanguageState.enabled() : entryEnabled = true;

  final bool entryEnabled;
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState.mock();
}
