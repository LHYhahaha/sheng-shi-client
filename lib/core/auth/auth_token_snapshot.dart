/// Auth token 快照，供网络层与 storage 边界使用。
///
/// 不进入 presentation/application UI 状态，也不放进 AuthSession domain。
/// [accessToken] 与 [refreshToken] 职责分离：前者用于业务 API Authorization，
/// 后者仅用于 refresh 流程。
class AuthTokenSnapshot {
  const AuthTokenSnapshot({
    this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresAt,
    this.refreshExpiresAt,
  });

  const AuthTokenSnapshot.empty()
    : accessToken = null,
      refreshToken = null,
      tokenType = 'Bearer',
      expiresAt = null,
      refreshExpiresAt = null;

  final String? accessToken;
  final String? refreshToken;
  final String tokenType;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;

  bool get hasAccessToken => accessToken != null && accessToken!.isNotEmpty;

  bool get hasRefreshToken => refreshToken != null && refreshToken!.isNotEmpty;

  bool get isEmpty => !hasAccessToken && !hasRefreshToken;

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'refreshExpiresAt': refreshExpiresAt?.toUtc().toIso8601String(),
    };
  }

  factory AuthTokenSnapshot.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return const AuthTokenSnapshot.empty();
    }

    return AuthTokenSnapshot(
      accessToken: _nullableString(json['accessToken']),
      refreshToken: _nullableString(json['refreshToken']),
      tokenType: _nullableString(json['tokenType']) ?? 'Bearer',
      expiresAt: _nullableDate(json['expiresAt']),
      refreshExpiresAt: _nullableDate(json['refreshExpiresAt']),
    );
  }

  static String? _nullableString(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  static DateTime? _nullableDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
