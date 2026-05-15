import 'package:flutter/foundation.dart';

/// API 请求上下文。
///
/// 这里集中所有接口都要带的基础 header。当前值是本地 mock/default，后续接真实
/// device id、app version、token storage 时，只替换 provider，不要让 feature 自己拼
/// header。
class ApiRequestContext {
  const ApiRequestContext({
    required this.deviceId,
    required this.lang,
    required this.platform,
    required this.appVersion,
    this.accessToken,
  });

  const ApiRequestContext.mock()
    : deviceId = 'mock-device-id',
      lang = 'en',
      platform = 'flutter',
      appVersion = '1.0.0',
      accessToken = null;

  /// 稳定设备/安装标识。
  ///
  /// 真实阶段应由设备标识服务或安装 id 提供，不能在各 feature 中临时生成。
  final String deviceId;

  /// 当前接口语言。
  ///
  /// 固定 UI 文案、内容语言、字幕语言后续会进一步拆分；网络层只负责透传当前请求语言。
  final String lang;

  /// 运行平台。
  final String platform;

  /// App 版本。
  final String appVersion;

  /// 当前访问 token。
  ///
  /// 登录、第三方登录、刷新 token 等接口应使用 ApiAuthPolicy.none，不带 Authorization。
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

String defaultApiPlatform() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
