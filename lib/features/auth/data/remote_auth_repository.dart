import '../../../core/network/api_request_context.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
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
  }) : _remoteDataSource = remoteDataSource,
       _requestContext = requestContext,
       _mapper = mapper;

  final AuthRemoteDataSource _remoteDataSource;
  final ApiRequestContext _requestContext;
  final AuthMapper _mapper;

  @override
  Future<AuthSession> fetchSession() async {
    final dto = await _remoteDataSource.fetchSession();
    return _mapper.mapSession(dto);
  }

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
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
}
