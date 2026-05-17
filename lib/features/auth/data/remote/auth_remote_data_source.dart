import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../dto/auth_session_dto.dart';
import '../dto/auth_token_dto.dart';
import '../dto/delete_account_request_dto.dart';
import '../dto/login_request_dto.dart';
import '../dto/logout_request_dto.dart';
import '../dto/oauth_login_request_dto.dart';
import '../dto/refresh_token_request_dto.dart';

/// Auth 远程数据源骨架。
///
/// 登录、第三方登录、刷新 token 不带 Authorization；logout/delete/session 依赖当前
/// session token，使用 required。真实 refresh 队列和 secure storage 不在本轮实现。
class AuthRemoteDataSource {
  const AuthRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthSessionDto> loginDevice(LoginRequestDto request) {
    return _apiClient.post<AuthSessionDto>(
      '/auth/login/device',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.none,
      decoder: AuthSessionDto.fromJson,
    );
  }

  Future<AuthSessionDto> loginOAuth(OAuthLoginRequestDto request) {
    return _apiClient.post<AuthSessionDto>(
      '/auth/login/oauth',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.none,
      decoder: AuthSessionDto.fromJson,
    );
  }

  Future<AuthTokenDto> refreshToken(RefreshTokenRequestDto request) {
    return _apiClient.post<AuthTokenDto>(
      '/auth/refresh',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.none,
      options: Options(extra: {apiSkipAuthRefreshExtraKey: true}),
      decoder: AuthTokenDto.fromJson,
    );
  }

  Future<AuthSessionDto> fetchSession() {
    return _apiClient.get<AuthSessionDto>(
      '/auth/session',
      authPolicy: ApiAuthPolicy.required,
      decoder: AuthSessionDto.fromJson,
    );
  }

  Future<AuthSessionDto> logout([
    LogoutRequestDto request = const LogoutRequestDto(),
  ]) {
    return _apiClient.post<AuthSessionDto>(
      '/auth/logout',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: AuthSessionDto.fromJson,
    );
  }

  Future<AuthSessionDto> deleteAccount([
    DeleteAccountRequestDto request = const DeleteAccountRequestDto(),
  ]) {
    return _apiClient.delete<AuthSessionDto>(
      '/account',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: AuthSessionDto.fromJson,
    );
  }
}
