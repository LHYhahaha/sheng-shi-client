import '../../../core/auth/auth_token_snapshot.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/auth/user_info_store.dart';
import '../../../core/network/api_request_context.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import 'dto/auth_session_dto.dart';
import 'dto/login_request_dto.dart';
import 'dto/oauth_login_request_dto.dart';
import 'mapper/auth_mapper.dart';
import 'remote/auth_remote_data_source.dart';

/// Auth 远程 repository 骨架。
///
/// 这里按现有 AuthRepository 接口返回 AuthSession，不向 UI 暴露 token。真实 token
/// 持久化和 ApiRequestContext 注入后续单独接入，避免本轮把敏感状态散到页面。
class RemoteAuthRepository implements AuthRepository {
  const RemoteAuthRepository({
    required AuthRemoteDataSource remoteDataSource,
    required ApiRequestContext requestContext,
    AuthMapper mapper = const AuthMapper(),
    AuthTokenStore? tokenStore,
    UserInfoStore? userInfoStore,
  }) : _remoteDataSource = remoteDataSource,
       _requestContext = requestContext,
       _mapper = mapper,
       _tokenStore = tokenStore,
       _userInfoStore = userInfoStore;

  final AuthRemoteDataSource _remoteDataSource;
  final ApiRequestContext _requestContext;
  final AuthMapper _mapper;
  final AuthTokenStore? _tokenStore;
  final UserInfoStore? _userInfoStore;

  @override
  Future<AuthSession> fetchSession() async {
    final dto = await _remoteDataSource.fetchSession();
    return _mapper.mapSession(dto);
  }

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    print('[RemoteAuthRepository] login starting with provider: $provider');
    print('[RemoteAuthRepository] deviceId: ${_requestContext.deviceId}');
    print('[RemoteAuthRepository] platform: ${_requestContext.platform}');
    print('[RemoteAuthRepository] appVersion: ${_requestContext.appVersion}');
    print('[RemoteAuthRepository] lang: ${_requestContext.lang}');
    
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
      AuthProviderType.facebook => await _remoteDataSource.loginOAuth(
        OAuthLoginRequestDto(
          provider: provider.name,
          // 本轮不接真实 SDK，token 字段只作为 remote skeleton contract。
          idToken: 'mock-${provider.name}-id-token',
          deviceId: _requestContext.deviceId,
          platform: _requestContext.platform,
          appVersion: _requestContext.appVersion,
          lang: _requestContext.lang,
        ),
      ),
    };
    
    print('[RemoteAuthRepository] login received response');
    await _saveToken(dto);
    print('[RemoteAuthRepository] login token saved');
    
    // 登录成功后获取用户信息
    print('[RemoteAuthRepository] fetching user info...');
    await _fetchAndSaveUserInfo();
    print('[RemoteAuthRepository] user info saved');
    
    return _mapper.mapSession(dto);
  }

  @override
  Future<AuthSession> logout() async {
    final dto = await _remoteDataSource.logout();
    return _mapper.mapSession(dto);
  }

  @override
  Future<AuthSession> deleteAccount() async {
    final dto = await _remoteDataSource.deleteAccount();
    return _mapper.mapSession(dto);
  }

  Future<void> _saveToken(AuthSessionDto dto) async {
    if (_tokenStore == null || dto.token == null) {
      print('[RemoteAuthRepository] _saveToken skipped: tokenStore=${_tokenStore != null}, token=${dto.token != null}');
      return;
    }

    final token = dto.token!;
    print('[RemoteAuthRepository] _saveToken saving token:');
    print('[RemoteAuthRepository]   accessToken: ${token.accessToken.substring(0, 20)}...');
    print('[RemoteAuthRepository]   refreshToken: ${token.refreshToken.substring(0, 20)}...');
    print('[RemoteAuthRepository]   expiresAt: ${token.expiresAt}');
    print('[RemoteAuthRepository]   refreshExpiresAt: ${token.refreshExpiresAt}');
    
    final snapshot = AuthTokenSnapshot(
      accessToken: token.accessToken,
      refreshToken: token.refreshToken,
      tokenType: token.tokenType,
      expiresAt: token.expiresAt,
      refreshExpiresAt: token.refreshExpiresAt,
      sessionKind: AuthTokenSessionKind.guest,
      guestId: token.accessToken,
    );

    await _tokenStore!.save(snapshot);
    print('[RemoteAuthRepository] _saveToken completed');
  }

  Future<void> _fetchAndSaveUserInfo() async {
    if (_userInfoStore == null) {
      print('[RemoteAuthRepository] _fetchAndSaveUserInfo skipped: userInfoStore is null');
      return;
    }

    try {
      final userInfoDto = await _remoteDataSource.getUserInfo();
      print('[RemoteAuthRepository] _fetchAndSaveUserInfo received:');
      print('[RemoteAuthRepository]   userId: ${userInfoDto.userId}');
      print('[RemoteAuthRepository]   nickname: ${userInfoDto.nickname}');
      print('[RemoteAuthRepository]   showId: ${userInfoDto.showId}');
      print('[RemoteAuthRepository]   coin: ${userInfoDto.coin}');
      print('[RemoteAuthRepository]   bonusCoin: ${userInfoDto.bonusCoin}');
      
      await _userInfoStore!.save(userInfoDto);
      print('[RemoteAuthRepository] _fetchAndSaveUserInfo completed');
    } catch (e) {
      print('[RemoteAuthRepository] _fetchAndSaveUserInfo failed: $e');
      // 获取用户信息失败不应该阻断登录流程，但需要记录错误
    }
  }
}
