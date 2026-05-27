import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'facebook_oauth_service.dart';
import 'oauth_service.dart';

/// Facebook OAuth 服务 provider。
///
/// 单例模式，整个应用共享一个实例。登出时会清除 SDK 缓存。
final facebookOAuthServiceProvider = Provider<OAuthService>((ref) {
  return FacebookOAuthService();
});
