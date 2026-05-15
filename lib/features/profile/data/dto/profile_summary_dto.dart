class ProfileMembershipSummaryDto {
  const ProfileMembershipSummaryDto({
    required this.isActive,
    this.planId,
    this.expiresAt,
  });

  final bool isActive;
  final String? planId;
  final DateTime? expiresAt;

  factory ProfileMembershipSummaryDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return ProfileMembershipSummaryDto(
      isActive: map['isActive'] == true,
      planId: _nullableString(map['planId']),
      expiresAt: _date(map['expiresAt']),
    );
  }
}

class ProfileWalletSummaryDto {
  const ProfileWalletSummaryDto({
    required this.coinBalance,
    required this.bonusBalance,
  });

  final int coinBalance;
  final int bonusBalance;

  factory ProfileWalletSummaryDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return ProfileWalletSummaryDto(
      coinBalance: _int(map['coinBalance']),
      bonusBalance: _int(map['bonusBalance']),
    );
  }
}

class ProfileSummaryDto {
  const ProfileSummaryDto({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.displayId,
    required this.membershipSummary,
    required this.walletSummary,
    required this.language,
    required this.region,
    this.createdAt,
  });

  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String displayId;
  final ProfileMembershipSummaryDto membershipSummary;
  final ProfileWalletSummaryDto walletSummary;
  final String language;
  final String region;
  final DateTime? createdAt;

  factory ProfileSummaryDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return ProfileSummaryDto(
      userId: _string(map['userId']),
      nickname: _string(map['nickname']),
      avatarUrl: _nullableString(map['avatarUrl']),
      displayId: _string(map['displayId']),
      membershipSummary: ProfileMembershipSummaryDto.fromJson(
        map['membershipSummary'],
      ),
      walletSummary: ProfileWalletSummaryDto.fromJson(map['walletSummary']),
      language: _string(map['language'], fallback: 'en'),
      region: _string(map['region']),
      createdAt: _date(map['createdAt']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
