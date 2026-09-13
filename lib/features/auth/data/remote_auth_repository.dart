import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../../core/auth/user_info_manager.dart';
import '../../../core/network/api_request_context.dart';
import '../../../core/oauth/oauth_service.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/delete_account_result.dart';
import 'dto/auth_session_dto.dart';
import 'dto/delete_account_request_dto.dart';
import 'dto/login_request_dto.dart';
import 'dto/oauth_login_request_dto.dart';
import 'remote/auth_remote_data_source.dart';

/// Auth 远程 repository 骨架。
///
/// 这里按现有 AuthRepository 接口返回 AuthSession，不向 UI 暴露 token。真实 token
/// 持久化和 ApiRequestContext 注入后续单独接入，避免本轮把敏感状态散到页面。
class RemoteAuthRepository
    implements AuthRepository, CurrentAuthSessionSynchronizer {
  const RemoteAuthRepository({
    required AuthRemoteDataSource remoteDataSource,
    required ApiRequestContext requestContext,
    AuthTokenStore? tokenStore,
    UserInfoStore? userInfoStore,
    OAuthService? oauthService,
  }) : _remoteDataSource = remoteDataSource,
       _requestContext = requestContext,
       _tokenStore = tokenStore,
       _userInfoStore = userInfoStore,
       _oauthService = oauthService;

  final AuthRemoteDataSource _remoteDataSource;
  final ApiRequestContext _requestContext;
  final AuthTokenStore? _tokenStore;
  final UserInfoStore? _userInfoStore;
  final OAuthService? _oauthService;

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    print('[RemoteAuthRepository] login starting with provider: $provider');
    print('[RemoteAuthRepository] deviceId: ${_requestContext.deviceId}');
    print('[RemoteAuthRepository] platform: ${_requestContext.platform}');
    print('[RemoteAuthRepository] appVersion: ${_requestContext.appVersion}');
    print('[RemoteAuthRepository] lang: ${_requestContext.lang}');

    final loginStopwatch = Stopwatch()..start();
    final dto = switch (provider) {
      AuthProviderType.device => await _remoteDataSource.loginDevice(
        LoginRequestDto(
          deviceId: _requestContext.deviceId,
          platform: _requestContext.platform,
          appVersion: _requestContext.appVersion,
          lang: _requestContext.lang,
        ),
      ),
      AuthProviderType.google ||
      AuthProviderType.facebook => await _loginWithOAuth(provider),
      AuthProviderType.phone => throw UnsupportedError(
        'Phone login requires SMS verification.',
      ),
    };

    if (provider == AuthProviderType.device) {
      debugPrint(
        '[StartupAuth] device login end '
        'elapsedMs=${loginStopwatch.elapsedMilliseconds}',
      );
    }
    print('[RemoteAuthRepository] login received response');
    await _saveToken(dto, provider: provider);
    print('[RemoteAuthRepository] login token saved');

    // 冷启动只保证 token 可用。完整用户资料随后的 /api/user/entitlements
    // 会统一同步到 UserInfoStore；不能额外请求 /api/user/get 并阻塞首屏。
    return const AuthSession.guest();
  }

  @override
  Future<AuthSession> syncCurrentSession() async {
    final userInfo = _userInfoStore?.snapshot;
    final provider = _providerFromToken(_tokenStore?.snapshot.provider);
    if (userInfo == null) {
      return const AuthSession.guest();
    }
    return UserInfoManager.buildSessionFromUserInfo(
      userInfo,
      provider: provider,
    );
  }

  @override
  Future<AuthSession> logout() async {
    final currentToken = _tokenStore?.snapshot;
    final shouldSignOutOAuth =
        currentToken?.hasAccessToken == true &&
        currentToken?.sessionKind != AuthTokenSessionKind.guest;
    final provider = _providerFromToken(currentToken?.provider);
    final success = await _remoteDataSource.logout();
    if (!success) {
      throw StateError('Logout failed.');
    }
    if (shouldSignOutOAuth) {
      await _signOutOAuth(provider);
    }
    return const AuthSession.guest();
  }

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    final currentToken = _tokenStore?.snapshot;
    final isGuest = currentToken?.sessionKind == AuthTokenSessionKind.guest;
    final shouldSignOutOAuth = currentToken?.hasAccessToken == true && !isGuest;
    final provider = _providerFromToken(currentToken?.provider);

    final response = await _remoteDataSource.deleteAccount(
      DeleteAccountRequestDto(
        acceptedRisk: true,
        deviceId: _requestContext.deviceId,
        sessionKind: currentToken?.sessionKind?.name,
        reason: 'account_cancellation',
      ),
    );

    if (!response.success) {
      throw StateError('Delete account failed.');
    }

    // 清理 OAuth 登录状态
    if (shouldSignOutOAuth) {
      await _signOutOAuth(provider);
    }

    // 清理本地 token 和用户信息
    await _tokenStore?.clear();
    await _userInfoStore?.clear();

    // 根据业务逻辑决定是否需要退出App
    // - 游客状态：直接退出App
    // - 三方登录且 isCurrentDeviceAccount == true：退出App
    // - 三方登录且 isCurrentDeviceAccount == false：返回me页面
    final shouldExitApp = isGuest || response.isCurrentDeviceAccount;

    return DeleteAccountResult(
      session: const AuthSession.guest(),
      shouldExitApp: shouldExitApp,
    );
  }

  /// 使用 OAuth 服务获取 token，然后调用后端登录接口。
  Future<AuthSessionDto> _loginWithOAuth(AuthProviderType provider) async {
    print(
      '[RemoteAuthRepository] _loginWithOAuth starting for provider: $provider',
    );

    // 获取 OAuth token
    String? oauthToken;
    try {
      if (_oauthService == null) {
        print(
          '[RemoteAuthRepository] _loginWithOAuth: oauthService is null, using mock token',
        );
        oauthToken = 'mock-${provider.name}-id-token';
      } else {
        print(
          '[RemoteAuthRepository] _loginWithOAuth: calling OAuth service...',
        );
        oauthToken = switch (provider) {
          AuthProviderType.facebook => await _oauthService.signInWithFacebook(),
          AuthProviderType.google => await _oauthService.signInWithGoogle(),
          _ => null,
        };

        if (oauthToken == null) {
          print('[RemoteAuthRepository] _loginWithOAuth: user cancelled login');
          throw OAuthLoginCancelledException(provider.name);
        }

        print(
          '[RemoteAuthRepository] _loginWithOAuth: got token: ${oauthToken.substring(0, 20)}...',
        );
      }
    } catch (e) {
      print('[RemoteAuthRepository] _loginWithOAuth: OAuth error: $e');
      rethrow;
    }

    // 调用后端登录接口
    print('[RemoteAuthRepository] _loginWithOAuth: calling backend API...');
    return await _remoteDataSource.loginOAuth(
      OAuthLoginRequestDto(provider: provider.name, token: oauthToken),
    );
  }

  Future<void> _saveToken(
    AuthSessionDto dto, {
    required AuthProviderType provider,
  }) async {
    if (_tokenStore == null || dto.token == null) {
      print(
        '[RemoteAuthRepository] _saveToken skipped: tokenStore=${_tokenStore != null}, token=${dto.token != null}',
      );
      return;
    }

    final token = dto.token!;
    print('[RemoteAuthRepository] _saveToken saving token:');
    print(
      '[RemoteAuthRepository]   accessToken: ${token.accessToken.substring(0, 20)}...',
    );
    print(
      '[RemoteAuthRepository]   refreshToken: ${token.refreshToken.substring(0, 20)}...',
    );
    print('[RemoteAuthRepository]   expiresAt: ${token.expiresAt}');
    print(
      '[RemoteAuthRepository]   refreshExpiresAt: ${token.refreshExpiresAt}',
    );

    // 如果服务器没有返回sessionId，使用accessToken的前16个字符作为sessionId
    final sessionId =
        dto.sessionId ?? 'sess-${token.accessToken.substring(0, 16)}';
    final guestId =
        dto.guestId ?? 'guest-${token.accessToken.substring(0, 16)}';

    print('[RemoteAuthRepository]   sessionId: $sessionId');
    print('[RemoteAuthRepository]   guestId: $guestId');

    final sessionKind =
        provider == AuthProviderType.device || dto.user?.isGuest == true
        ? AuthTokenSessionKind.guest
        : AuthTokenSessionKind.authenticated;

    final snapshot = AuthTokenSnapshot(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      tokenType: token.tokenType,
      expiresAt: token.expiresAt,
      refreshExpiresAt: token.refreshExpiresAt,
      sessionKind: sessionKind,
      subjectId: sessionId,
      guestId: guestId,
      provider: provider.name,
    );

    final tokenWriteStopwatch = Stopwatch()..start();
    await _tokenStore.save(snapshot);
    if (provider == AuthProviderType.device) {
      debugPrint(
        '[StartupAuth] token write end '
        'elapsedMs=${tokenWriteStopwatch.elapsedMilliseconds}',
      );
    }
    print('[RemoteAuthRepository] _saveToken completed');
  }

  AuthProviderType _providerFromToken(String? value) {
    return switch (value) {
      'facebook' => AuthProviderType.facebook,
      'google' => AuthProviderType.google,
      'phone' => AuthProviderType.phone,
      _ => AuthProviderType.device,
    };
  }

  Future<void> _signOutOAuth(AuthProviderType provider) async {
    try {
      switch (provider) {
        case AuthProviderType.facebook:
          await _oauthService?.signOutFacebook();
        case AuthProviderType.google:
          await _oauthService?.signOutGoogle();
        case AuthProviderType.phone:
        case AuthProviderType.device:
          break;
      }
    } catch (error) {
      print('[RemoteAuthRepository] OAuth sign out skipped: $error');
    }
  }
}
