import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'oauth_service.dart';

/// Facebook OAuth 服务实现。
///
/// 封装 flutter_facebook_auth SDK，处理登录流程和错误。上层只需要调用
/// [signInWithFacebook] 获取 access token，不需要关心 SDK 细节。
class FacebookOAuthService implements OAuthService {
  FacebookOAuthService({FacebookAuth? facebookAuth})
    : _facebookAuth = facebookAuth ?? FacebookAuth.instance;

  final FacebookAuth _facebookAuth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitializeFuture;

  Future<void> _initializeGoogleSignIn() {
    if (_googleServerClientId.isEmpty) {
      throw const OAuthException(
        'google',
        'Missing GOOGLE_SERVER_CLIENT_ID build configuration',
      );
    }
    return _googleInitializeFuture ??= _googleSignIn.initialize(
      // 始终显式注入 Web OAuth Client ID，不依赖 google-services.json。
      serverClientId: _googleServerClientId,
    );
  }

  @override
  Future<String?> signInWithFacebook() async {
    try {
      // 1. 调用 Facebook 登录
      final LoginResult result = await _facebookAuth.login(
        permissions: ['email', 'public_profile'],
      );

      // 2. 处理登录结果
      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken;
          if (accessToken == null) {
            throw const OAuthException(
              'facebook',
              'Login succeeded but access token is null',
            );
          }
          // AccessToken 的 token 属性包含实际的 token 字符串
          return accessToken.token;

        case LoginStatus.cancelled:
          // 用户取消登录，返回 null
          return null;

        case LoginStatus.failed:
          throw OAuthException('facebook', result.message ?? 'Login failed');

        case LoginStatus.operationInProgress:
          throw const OAuthException(
            'facebook',
            'Another login operation is in progress',
          );
      }
    } catch (e) {
      if (e is OAuthException) {
        rethrow;
      }
      throw OAuthException('facebook', 'Unexpected error during login', e);
    }
  }

  @override
  Future<void> signOutFacebook() async {
    try {
      await _facebookAuth.logOut();
    } catch (e) {
      // 登出失败不应该阻塞流程，只记录日志
      print('Failed to sign out from Facebook: $e');
    }
  }

  /// 获取当前 Facebook 登录状态（可选，用于调试）。
  Future<AccessToken?> getCurrentAccessToken() async {
    try {
      return await _facebookAuth.accessToken;
    } catch (e) {
      print('Failed to get current access token: $e');
      return null;
    }
  }

  /// 获取用户信息（可选，用于调试或显示）。
  ///
  /// 返回的数据包含：id, name, email, picture 等字段。
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      return await _facebookAuth.getUserData();
    } catch (e) {
      print('Failed to get user data: $e');
      return null;
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    try {
      await _initializeGoogleSignIn();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const OAuthException(
          'google',
          'Google sign-in is not supported on this platform',
        );
      }

      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const OAuthException(
          'google',
          'Login succeeded but Google ID token is missing',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw OAuthException(
        'google',
        error.description ?? 'Login failed',
        error,
      );
    } catch (error) {
      if (error is OAuthException) {
        rethrow;
      }
      throw OAuthException('google', 'Unexpected error during login', error);
    }
  }

  @override
  Future<String?> signInWithApple() {
    throw UnimplementedError('Apple login not implemented yet');
  }

  @override
  Future<void> signOutGoogle() async {
    try {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
    } catch (error) {
      print('Failed to sign out from Google: $error');
    }
  }
}

/// Google Cloud Console 中的 Web OAuth Client ID。
///
/// 通过构建参数写入 App，例如：
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`。
/// 不要在客户端写入 OAuth Client Secret。
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
