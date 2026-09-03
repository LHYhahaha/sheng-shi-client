import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 应用运行环境。
///
/// 环境只影响 baseUrl 等基础配置，不应在业务代码里用环境分支绕过状态机或权限判断。
enum AppEnvironment { dev, staging, prod }

/// 应用级静态配置。
///
/// 当前通过 `--dart-define=APP_ENV` 选择环境，便于测试和打包保持确定性。后续如果接
/// 远程配置，也应该只覆盖可调策略，不要远程改 API host 这类启动前必须稳定的值。
class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  /// 当前环境。
  final AppEnvironment environment;

  /// 生产环境不输出客户端开发日志，避免在正式包日志中暴露请求或会话信息。
  bool get isProduction => environment == AppEnvironment.prod;
  // bool get isProduction => false;

  /// API base URL。
  ///
  /// 仅网络层使用，业务页面不要根据 URL 判断环境或行为。
  final Uri apiBaseUrl;

  /// 问题与帮助 H5 地址。
  ///
  /// 语言由应用当前 locale 提供，避免 H5 与客户端语言不一致。
  Uri helpUrlForLanguage(
    String languageCode, {
    String userId = '',
    String channelId = '',
    String merchantId = '',
    String previousPage = '',
  }) {
    final baseUrl = _webBaseUrl.replace(path: '/app/');

    return baseUrl.replace(
      queryParameters: {
        ..._h5CommonParameters(
          languageCode: languageCode,
          userId: userId,
          channelId: channelId,
          merchantId: merchantId,
        ),
        'previous_page': previousPage,
      },
      fragment: '/help',
    );
  }

  /// 隐私政策 H5 地址。
  Uri privacyPolicyUrlForLanguage(String languageCode) => _webBaseUrl.replace(
    path: '/legal/privacy/index.html',
    queryParameters: {'lang': languageCode},
  );

  /// 用户协议 H5 地址。
  Uri termsOfUseUrlForLanguage(String languageCode) => _webBaseUrl.replace(
    path: '/legal/terms/index.html',
    queryParameters: {'lang': languageCode},
  );

  /// 剧集分享页 H5 地址。
  Uri shareUrl({
    required String dramaId,
    required String languageCode,
    String userId = '',
    String channelId = '',
    String merchantId = '',
    String shareMethod = '',
  }) => _webBaseUrl.replace(
    path: '/share/',
    queryParameters: {
      'drama_id': dramaId,
      ..._h5CommonParameters(
        languageCode: languageCode,
        userId: userId,
        channelId: channelId,
        merchantId: merchantId,
      ),
      'share_method': shareMethod,
    },
  );

  /// Facebook 分享页使用单一的 `_sp` 参数承载原有分享字段；复制链接仍使用
  /// [shareUrl] 的可读查询参数格式，不受此方法影响。
  Uri facebookShareUrl({
    required String dramaId,
    required String languageCode,
    String userId = '',
    String channelId = '',
    String merchantId = '',
  }) {
    final packed = _packShareQuery({
      'drama_id': dramaId,
      'lang': languageCode,
      'user_id': userId,
      'channel_id': channelId,
      'merchant_id': merchantId,
      'share_method': 'facebook',
    });
    return _webBaseUrl.replace(
      path: '/share/',
      queryParameters: {'_sp': packed},
    );
  }

  /// 赠送会员 H5 地址。当前客户端尚无赠送入口，先保留完整参数契约。
  Uri giftVipUrl({
    required String languageCode,
    String userId = '',
    String channelId = '',
    String merchantId = '',
    String shareMethod = '',
    String shareCode = '',
    String benefitDays = '',
  }) => _webBaseUrl.replace(
    path: '/gift/vip/',
    queryParameters: {
      ..._h5CommonParameters(
        languageCode: languageCode,
        userId: userId,
        channelId: channelId,
        merchantId: merchantId,
      ),
      'share_method': shareMethod,
      'shareCode': shareCode,
      'benefitDays': benefitDays,
    },
  );

  /// 赠送短剧 H5 地址。当前客户端尚无赠送入口，先保留完整参数契约。
  Uri giftDramaUrl({
    required String languageCode,
    required String dramaId,
    String userId = '',
    String channelId = '',
    String merchantId = '',
    String shareMethod = '',
    String shareCode = '',
    String benefitDays = '',
  }) => _webBaseUrl.replace(
    path: '/gift/drama/',
    queryParameters: {
      ..._h5CommonParameters(
        languageCode: languageCode,
        userId: userId,
        channelId: channelId,
        merchantId: merchantId,
      ),
      'share_method': shareMethod,
      'shareCode': shareCode,
      'benefitDays': benefitDays,
      'drama_id': dramaId,
    },
  );

  /// Facebook 赠送会员链接沿用普通分享的 `_sp` 打包格式；复制链接继续使用
  /// [giftVipUrl] 的可读查询参数格式。
  Uri facebookGiftVipUrl({
    required String languageCode,
    String userId = '',
    String channelId = '',
    String merchantId = '',
    String shareCode = '',
    String benefitDays = '',
  }) => _facebookGiftUrl(
    path: '/gift/vip/',
    languageCode: languageCode,
    userId: userId,
    channelId: channelId,
    merchantId: merchantId,
    shareCode: shareCode,
    benefitDays: benefitDays,
  );

  /// Facebook 赠送短剧链接沿用普通分享的 `_sp` 打包格式。
  Uri facebookGiftDramaUrl({
    required String languageCode,
    required String dramaId,
    String userId = '',
    String channelId = '',
    String merchantId = '',
    String shareCode = '',
    String benefitDays = '',
  }) => _facebookGiftUrl(
    path: '/gift/drama/',
    languageCode: languageCode,
    userId: userId,
    channelId: channelId,
    merchantId: merchantId,
    shareCode: shareCode,
    benefitDays: benefitDays,
    dramaId: dramaId,
  );

  Uri _facebookGiftUrl({
    required String path,
    required String languageCode,
    required String userId,
    required String channelId,
    required String merchantId,
    required String shareCode,
    required String benefitDays,
    String dramaId = '',
  }) {
    final packed = _packShareQuery({
      'lang': languageCode,
      'user_id': userId,
      'channel_id': channelId,
      'merchant_id': merchantId,
      'share_method': 'facebook',
      'shareCode': shareCode,
      'benefitDays': benefitDays,
      'drama_id': dramaId,
    });
    return _webBaseUrl.replace(path: path, queryParameters: {'_sp': packed});
  }

  Map<String, String> _h5CommonParameters({
    required String languageCode,
    required String userId,
    required String channelId,
    required String merchantId,
  }) => {
    'lang': languageCode,
    'user_id': userId,
    'channel_id': channelId,
    'merchant_id': merchantId,
  };

  String _packShareQuery(Map<String, String> parameters) {
    final query = parameters.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    debugPrint('[Share] _sp payload before encoding: $query');
    return base64Url.encode(utf8.encode(query)).replaceAll('=', '');
  }

  Uri get _webBaseUrl => switch (environment) {
    AppEnvironment.prod => Uri.parse('https://juan365drama.com/'),
    AppEnvironment.dev || AppEnvironment.staging => Uri.parse(
      'https://drama-wave.8y4w2vxvdffmd83.xyz/',
    ),
  };

  static final current = AppConfig.forEnvironment(_environmentFromDefine);

  static AppConfig forEnvironment(
    AppEnvironment environment, {
    String? apiBaseUrlOverride,
  }) {
    final override = apiBaseUrlOverride ?? _apiBaseUrlOverrideFromDefine;
    if (override != null && override.isNotEmpty) {
      return AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse(override),
      );
    }

    return switch (environment) {
      AppEnvironment.dev => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://gateway-api.8y4w2vxvdffmd83.xyz'),
        //http://192.168.1.15:8888
      ),
      AppEnvironment.staging => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://staging-api.example.com'),
      ),
      AppEnvironment.prod => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://gateway-api.3ype43hnuvw82h67e523.xyz'),
      ),
    };
  }

  static String? get _apiBaseUrlOverrideFromDefine {
    const value = String.fromEnvironment('API_BASE_URL');
    return value.isEmpty ? null : value;
  }

  static AppEnvironment get _environmentFromDefine {
    const value = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

    return switch (value) {
      'prod' => AppEnvironment.prod,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.dev,
    };
  }
}
