import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'oauth_service.dart';

/// Facebook OAuth 服务实现。
///
/// 封装 flutter_facebook_auth SDK，处理登录流程和错误。上层只需要调用
/// [signInWithFacebook] 获取 access token，不需要关心 SDK 细节。
class FacebookOAuthService implements OAuthService {
  // 未安装 Facebook App 时会跳到浏览器，用户输入密码、二次验证的时间远超
  // 原先的 15 秒。过早超时会主动关闭 SDK Activity，导致网页已授权却无法回调。
  static const _facebookAuthorizationTimeout = Duration(minutes: 2);
  static const _facebookCleanupTimeout = Duration(seconds: 5);
  static const _facebookRecoveryChannel = MethodChannel(
    'com.yushi.drama/facebook_auth_recovery',
  );

  FacebookOAuthService({
    FacebookAuth? facebookAuth,
    Future<AuthorizationCredentialAppleID> Function()? requestAppleCredential,
  }) : _facebookAuth = facebookAuth ?? FacebookAuth.instance,
       _requestAppleCredential =
           requestAppleCredential ?? _requestAppleCredentialFromNative;

  final FacebookAuth _facebookAuth;
  final Future<AuthorizationCredentialAppleID> Function()
  _requestAppleCredential;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  Future<void>? _googleInitializeFuture;

  static Future<AuthorizationCredentialAppleID>
  _requestAppleCredentialFromNative() {
    return SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
  }

  /// 仅用于定位 Limited Login 返回字段；认证可信性仍必须由服务端校验 JWT。
  @visibleForTesting
  static Map<String, dynamic>? decodeJwtPayloadForLogging(String token) {
    final segments = token.split('.');
    if (segments.length != 3) {
      return null;
    }

    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return decoded is Map<String, dynamic>
          ? decoded
          : Map<String, dynamic>.from(decoded as Map);
    } catch (_) {
      return null;
    }
  }

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
      debugPrint(
        '[FacebookOAuth] Starting native authorization '
        'platform=${defaultTargetPlatform.name}',
      );
      // 1. 调用 Facebook 登录
      final LoginResult result = await _facebookAuth
          .login(
            permissions: ['email', 'public_profile'],
            // 7.x 在 iOS 默认启用 limited login，会返回无法直接用于现有
            // Facebook 后端登录接口的 OIDC token。保持原有 classic token 协议。
            loginTracking: LoginTracking.enabled,
          )
          .timeout(
            _facebookAuthorizationTimeout,
            onTimeout: () async {
              // 超时不仅要释放 Dart Future，也要结束仍停在前台的 Android
              // FacebookActivity，否则用户看到的原生 loading 会一直存在。
              debugPrint(
                '[FacebookOAuth] Authorization timed out after '
                '${_facebookAuthorizationTimeout.inSeconds}s; recovering.',
              );
              await _finishStuckFacebookActivity();
              await _resetFacebookLoginState();
              throw TimeoutException('Facebook authorization timed out');
            },
          );

      // 2. 处理登录结果
      debugPrint(
        '[FacebookOAuth] Native authorization result: '
        'status=${result.status.name}, hasAccessToken=${result.accessToken != null}',
      );
      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken;
          if (accessToken == null) {
            throw const OAuthException(
              'facebook',
              'Login succeeded but access token is null',
              null,
              OAuthFailureReason.credentialMissing,
            );
          }
          if (accessToken is! ClassicToken) {
            final limitedToken = accessToken as LimitedToken;
            debugPrint(
              '[FacebookOAuth] Limited Login JWT: '
              '${limitedToken.tokenString}',
            );
            debugPrint(
              '[FacebookOAuth] Limited Login response: '
              '${jsonEncode(limitedToken.toJson())}',
            );
            debugPrint(
              '[FacebookOAuth] Limited Login JWT payload: '
              '${jsonEncode(decodeJwtPayloadForLogging(limitedToken.tokenString))}',
            );
            throw const OAuthException(
              'facebook',
              'Limited Facebook login is not supported by this backend.',
            );
          }
          return accessToken.tokenString;

        case LoginStatus.cancelled:
          // 用户取消登录，返回 null
          return null;

        case LoginStatus.failed:
          throw OAuthException('facebook', result.message ?? 'Login failed');

        case LoginStatus.operationInProgress:
          // SDK 仍持有上一轮的 Activity（常见于退出授权页时）。单纯 logOut
          // 不会关闭这个 Activity，下一次 login 会继续卡在同一个请求上。
          await _finishStuckFacebookActivity();
          await _resetFacebookLoginState();
          throw const OAuthException(
            'facebook',
            'A previous Facebook login did not finish. Please try again.',
          );
      }
    } catch (error) {
      debugPrint('[FacebookOAuth] Native authorization failed: $error');
      if (error is TimeoutException) {
        rethrow;
      }
      if (error is OAuthException) {
        rethrow;
      }
      // 平台回调异常时，也可能遗留 FacebookActivity/CustomTabActivity；先关闭它
      // 再清 token，确保下一次授权从干净状态开始。
      await _finishStuckFacebookActivity();
      await _resetFacebookLoginState();
      throw OAuthException('facebook', 'Unexpected error during login', error);
    }
  }

  Future<void> _resetFacebookLoginState() async {
    try {
      debugPrint('[FacebookOAuth] Resetting SDK login state.');
      await _facebookAuth.logOut().timeout(_facebookCleanupTimeout);
      debugPrint('[FacebookOAuth] SDK login state reset complete.');
    } catch (error) {
      // 清理失败不能继续阻塞登录页；外层会释放 pending 状态并允许用户重试。
      debugPrint('[FacebookOAuth] Failed to reset login state: $error');
    }
  }

  Future<void> _finishStuckFacebookActivity() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _facebookRecoveryChannel
          .invokeMethod<void>('finishFacebookActivity')
          .timeout(_facebookCleanupTimeout);
      debugPrint('[FacebookOAuth] Requested Android FacebookActivity close.');
    } catch (error) {
      // 原生活动已经自行关闭或通道不可用时，仍继续释放登录状态。
      debugPrint('[FacebookOAuth] Failed to close Facebook activity: $error');
    }
  }

  @override
  Future<void> signOutFacebook() async {
    // Facebook SDK 的 logOut 只删除本地 token，不负责销毁已经停滞的授权页。
    // 退出应用账号后必须连同授权 Activity 一并收尾，否则再次登录会命中
    // `operationInProgress` 并在原生 loading 页停住。
    await _finishStuckFacebookActivity();
    await _resetFacebookLoginState();
  }

  /// 获取当前 Facebook 登录状态（可选，用于调试）。
  Future<AccessToken?> getCurrentAccessToken() async {
    try {
      return await _facebookAuth.accessToken;
    } catch (e) {
      debugPrint('Failed to get current access token: $e');
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
      debugPrint('Failed to get user data: $e');
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
          null,
          OAuthFailureReason.credentialMissing,
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
  Future<String?> signInWithApple() async {
    try {
      debugPrint('[AppleOAuth] Starting native authorization.');
      final credential = await _requestAppleCredential();
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const OAuthException(
          'apple',
          'Apple authorization succeeded but identity token is missing',
          null,
          OAuthFailureReason.credentialMissing,
        );
      }

      debugPrint(
        '[AppleOAuth] Native authorization credential: '
        'userIdentifier=${credential.userIdentifier}, '
        'givenName=${credential.givenName}, '
        'familyName=${credential.familyName}, '
        'email=${credential.email}, '
        'authorizationCode=${credential.authorizationCode}, '
        'identityToken=$identityToken',
      );
      return identityToken;
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw OAuthException('apple', error.message, error);
    } on OAuthException {
      rethrow;
    } catch (error) {
      throw OAuthException('apple', 'Unexpected error during login', error);
    }
  }

  @override
  Future<void> signOutGoogle() async {
    try {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('Failed to sign out from Google: $error');
    }
  }
}

/// Google Cloud Console 中的 Web OAuth Client ID。
///
/// 通过构建参数写入 App，例如：
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`。
/// 不要在客户端写入 OAuth Client Secret。
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
