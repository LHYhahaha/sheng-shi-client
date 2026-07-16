/// API 请求上下文。
///
/// 基础 header（Device-Id / Lang / Platform / App-Version / Region-Code）由 runtime provider 注入，
/// 见 [apiRequestContextProvider]。feature 不得自行拼装这些 header。
class ApiRequestContext {
  const ApiRequestContext({
    required this.deviceId,
    required this.lang,
    required this.platform,
    required this.appVersion,
    this.regionCode = '',
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
    this.sessionId,
    this.guestId,
  });

  /// 仅用于单元测试；生产路径使用 [apiRequestContextProvider]。
  const ApiRequestContext.test({
    this.deviceId = 'test-install-id',
    this.lang = 'en',
    this.platform = 'android',
    this.appVersion = '1.0.0',
    this.regionCode = '',
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.refreshTokenExpiresAt,
    this.sessionId,
    this.guestId,
  });

  /// 安装级 install id，映射为 `Device-Id` header。
  ///
  /// 不是硬件唯一 ID；清 App 数据后会重新生成。guest bootstrap / account link 依赖此值。
  final String deviceId;

  /// 接口语言（en / zh）；由 [apiLangProvider] 映射，不支持语言 fallback en。
  final String lang;

  /// 运行平台：android / ios / web 等。
  final String platform;

  /// 应用版本号（如 1.0.0）。
  final String appVersion;

  /// 设备地区码（如 SG）；系统未提供地区时为空字符串。
  final String regionCode;

  /// 当前 access token；refresh token 不在此暴露。
  final String? accessToken;

  /// 当前 refresh token；仅用于 token 刷新流程。
  final String? refreshToken;

  /// access token 的过期时间。
  final DateTime? accessTokenExpiresAt;

  /// refresh token 的过期时间。
  final DateTime? refreshTokenExpiresAt;

  /// 服务端 session id（游客或正式用户）。
  final String? sessionId;

  /// 游客 id，account link 时传给服务端。
  final String? guestId;

  Map<String, String> toBaseHeaders() {
    final headers = {
      'Device-Id': deviceId,
      'Lang': lang,
      'Platform': platform,
      'App-Version': appVersion,
      'Region-Code': regionCode,
      'Accept': 'application/json',
    };

    if (sessionId != null && sessionId!.isNotEmpty) {
      headers['Session-Id'] = sessionId!;
    }

    if (guestId != null && guestId!.isNotEmpty) {
      headers['Guest-Id'] = guestId!;
    }

    return headers;
  }
}
