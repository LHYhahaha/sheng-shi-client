/// Token 对应的 session 主体类型（网络/storage 层，不进 UI）。
///
/// guest 与 authenticated 都可以有 access/refresh token；`ApiAuthPolicy.required`
/// 当前表示“需要任意有效 session token”，尚未区分 guest vs 正式用户。
enum AuthTokenSessionKind { guest, authenticated }

/// Auth token 快照，供网络层与 storage 边界使用。
///
/// 不进入 presentation/application UI 状态，也不放进 [AuthSession] domain。
/// [accessToken] 与 [refreshToken] 职责分离：前者用于业务 API Authorization，
/// 后者仅用于 refresh 流程（UI 不得读取 refreshToken）。
///
/// token 可能属于游客 session，也可能属于 account link 后的正式用户 session。
/// [sessionKind] / [subjectId] / [guestId] 为真实 API 阶段扩展字段，mock 阶段可为空。
class AuthTokenSnapshot {
  const AuthTokenSnapshot({
    this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresAt,
    this.refreshExpiresAt,
    this.sessionKind,
    this.subjectId,
    this.guestId,
  });

  const AuthTokenSnapshot.empty()
    : accessToken = null,
      refreshToken = null,
      tokenType = 'Bearer',
      expiresAt = null,
      refreshExpiresAt = null,
      sessionKind = null,
      subjectId = null,
      guestId = null;

  final String? accessToken;
  final String? refreshToken;
  final String tokenType;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;

  /// 当前 token 绑定的 session 类型；真实 bootstrap / login 后由服务端声明。
  final AuthTokenSessionKind? sessionKind;

  /// 主体 id：游客 guestId 或正式 userId（与 [guestId] 区分，见产品文档）。
  final String? subjectId;

  /// account link 用的游客锚点 id（登录请求携带，便于服务端合并游客数据）。
  final String? guestId;

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
      'sessionKind': sessionKind?.name,
      'subjectId': subjectId,
      'guestId': guestId,
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
      sessionKind: _sessionKindFromJson(json['sessionKind']),
      subjectId: _nullableString(json['subjectId']),
      guestId: _nullableString(json['guestId']),
    );
  }

  static AuthTokenSessionKind? _sessionKindFromJson(Object? value) {
    if (value == AuthTokenSessionKind.guest.name) {
      return AuthTokenSessionKind.guest;
    }
    if (value == AuthTokenSessionKind.authenticated.name) {
      return AuthTokenSessionKind.authenticated;
    }
    return null;
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
