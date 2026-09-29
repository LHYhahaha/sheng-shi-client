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

  /// 使用 Facebook 登录，返回服务端登录所需的凭证及其类型。
  ///
  /// 返回 null 表示用户取消登录。抛出异常表示登录失败。
  Future<FacebookLoginCredential?> signInWithFacebook();

  /// 使用 Apple 登录，返回服务端换取应用会话所需的授权凭证（iOS 专用）。
  ///
  /// 返回 null 表示用户取消登录。抛出异常表示登录失败。
  ///
  /// 注意：当前项目暂不支持 Apple 登录，此方法预留给未来使用。
  Future<AppleLoginCredential?> signInWithApple() {
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

/// Apple 原生授权返回、且服务端 Apple 登录接口需要的凭证。
///
/// email 和姓名仅会在首次授权时返回；不能因为后续为空而覆盖服务端已有资料。
class AppleLoginCredential {
  const AppleLoginCredential({
    required this.identityToken,
    this.authorizationCode,
    this.email,
    this.fullName,
  });

  final String identityToken;
  final String? authorizationCode;
  final String? email;
  final String? fullName;
}

/// Facebook SDK 返回的登录凭证。
///
/// 受限登录和经典登录使用不同的服务端请求字段，不能只将 token 当作字符串传递。
class FacebookLoginCredential {
  const FacebookLoginCredential._(this.token, this.type);

  const FacebookLoginCredential.classic(String token)
    : this._(token, FacebookLoginCredentialType.classic);

  const FacebookLoginCredential.limited(String token)
    : this._(token, FacebookLoginCredentialType.limited);

  final String token;
  final FacebookLoginCredentialType type;
}

enum FacebookLoginCredentialType { classic, limited }

/// OAuth 登录异常。
enum OAuthFailureReason { sdkError, credentialMissing }

class OAuthException implements Exception {
  const OAuthException(
    this.provider,
    this.message, [
    this.originalError,
    this.reason = OAuthFailureReason.sdkError,
  ]);

  final String provider;
  final String message;
  final Object? originalError;
  final OAuthFailureReason reason;

  @override
  String toString() => 'OAuthException($provider): $message';
}

class OAuthLoginCancelledException implements Exception {
  const OAuthLoginCancelledException(this.provider);

  final String provider;

  @override
  String toString() => 'OAuthLoginCancelledException($provider)';
}
