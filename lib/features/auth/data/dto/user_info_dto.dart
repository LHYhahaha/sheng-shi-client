import '../../../../core/network/json_field_parser.dart';

/// 用户详细信息 DTO。
///
/// 登录后调用 /api/user/get 获取的用户完整信息。
class UserInfoDto {
  const UserInfoDto({
    required this.showId,
    required this.nickname,
    this.userId,
    this.avatar,
    this.language,
    this.status,
    this.vipExpireAt,
    this.coin,
    this.bonusCoin,
    this.autoUnlock,
  });

  final int? userId;
  final String showId;
  final String nickname;
  final String? avatar;
  final String? language;
  final int? status;
  final String? vipExpireAt;
  final int? coin;
  final int? bonusCoin;
  final int? autoUnlock;

  factory UserInfoDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'UserInfoDto');

    return UserInfoDto(
      userId: JsonFieldParser.optionalInt(map, 'userId'),
      showId: _requiredShowId(map),
      nickname:
          JsonFieldParser.optionalString(map, 'nickname') ??
          JsonFieldParser.optionalString(map, 'nickName') ??
          _requiredShowId(map),
      avatar: _optionalAvatar(map),
      language: JsonFieldParser.optionalString(map, 'language'),
      status: JsonFieldParser.optionalInt(map, 'status'),
      vipExpireAt: JsonFieldParser.optionalString(map, 'vipExpireAt'),
      coin: JsonFieldParser.optionalInt(map, 'coin'),
      bonusCoin: JsonFieldParser.optionalInt(map, 'bonusCoin'),
      autoUnlock: JsonFieldParser.optionalInt(map, 'autoUnlock'),
    );
  }

  Map<String, Object?> toJson() => {
    if (userId != null) 'userId': userId,
    'showId': showId,
    'nickname': nickname,
    'avatar': avatar,
    'language': language,
    'status': status,
    'vipExpireAt': vipExpireAt,
    'coin': coin,
    'bonusCoin': bonusCoin,
    'autoUnlock': autoUnlock,
  };
}

String _requiredShowId(Map<String, Object?> map) {
  final showId =
      JsonFieldParser.optionalString(map, 'showId') ??
      JsonFieldParser.optionalString(map, 'showid');
  if (showId == null || showId.isEmpty) {
    return JsonFieldParser.requireString(map, 'showId', dtoName: 'UserInfoDto');
  }
  return showId;
}

String? _optionalAvatar(Map<String, Object?> map) {
  return JsonFieldParser.optionalString(map, 'avatar') ??
      JsonFieldParser.optionalString(map, 'avatarUrl') ??
      JsonFieldParser.optionalString(map, 'avatar_url');
}
