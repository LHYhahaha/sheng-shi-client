/// API 请求上下文。
///
/// 基础 header（Device-Id / Lang / Platform / App-Version）由 runtime provider 注入，
/// 见 [apiRequestContextProvider]。feature 不得自行拼装这些 header。
class ApiRequestContext {
  const ApiRequestContext({
    required this.deviceId,
    required this.lang,
    required this.platform,
    required this.appVersion,
    this.accessToken,
  });

  /// 仅用于单元测试；生产路径使用 [apiRequestContextProvider]。
  const ApiRequestContext.test({
    this.deviceId = 'test-install-id',
    this.lang = 'en',
    this.platform = 'android',
    this.appVersion = '1.0.0',
    this.accessToken,
  });

  /// 安装级 install id，映射为 `Device-Id` header。
  ///
  /// 不是硬件唯一 ID；清 App 数据后会重新生成。guest bootstrap / account link 依赖此值。
  final String deviceId;

  /// 接口语言（en / es / pt / hi）；由 [apiLangProvider] 映射，不支持语言 fallback en。
  final String lang;

  /// 运行平台：android / ios / web 等。
  final String platform;

  /// 应用版本号（如 1.0.0）。
  final String appVersion;

  /// 当前 access token；refresh token 不在此暴露。
  final String? accessToken;

  Map<String, String> toBaseHeaders() {
    return {
      'Device-Id': deviceId,
      'Lang': lang,
      'Platform': platform,
      'App-Version': appVersion,
      'Accept': 'application/json',
    };
  }
}
