/// OAuth 第三方登录服务抽象。
///
/// 封装 Google/Facebook/Apple 等第三方 SDK 的登录流程，返回标准化的 token。
/// 这一层不应该依赖 AuthRepository 或 AuthSession，只负责调用平台 SDK 并返回
/// token 字符串。真实 session 构建由 RemoteAuthRepository 完成。
abstract class OAuthService {
  /// 使用 Google 登录，返回 ID Token。
  ///
  /// 返回 null 表示用户取消登录。抛出异常表示登录失败。
  /// 
  /// 注意：当前项目暂不支持 Google 登录，此方法预留给未来使用。
  Future<String?> signInWithGoogle() {
    throw UnimplementedError('Google login not implemented yet');
  }

  /// 使用 Facebook 登录，返回 Access Token。
  ///
  /// 返回 null 表示用户取消登录。抛出异常表示登录失败。
  Future<String?> signInWithFacebook();

  /// 使用 Apple 登录，返回 ID Token（iOS 专用）。
  ///
  /// 返回 null 表示用户取消登录。抛出异常表示登录失败。
  /// 
  /// 注意：当前项目暂不支持 Apple 登录，此方法预留给未来使用。
  Future<String?> signInWithApple() {
    throw UnimplementedError('Apple login not implemented yet');
  }

  /// 登出 Google 账号（清除本地缓存）。
  /// 
  /// 注意：当前项目暂不支持 Google 登录，此方法预留给未来使用。
  Future<void> signOutGoogle() {
    throw UnimplementedError('Google login not implemented yet');
  }

  /// 登出 Facebook 账号（清除本地缓存）。
  Future<void> signOutFacebook();
}

/// OAuth 登录异常。
class OAuthException implements Exception {
  const OAuthException(this.provider, this.message, [this.originalError]);

  final String provider;
  final String message;
  final Object? originalError;

  @override
  String toString() => 'OAuthException($provider): $message';
}
