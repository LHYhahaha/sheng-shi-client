import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../dto/auth_session_dto.dart';
import '../dto/auth_token_dto.dart';
import '../dto/delete_account_request_dto.dart';
import '../dto/login_request_dto.dart';
import '../dto/logout_request_dto.dart';
import '../dto/oauth_login_request_dto.dart';
import '../dto/refresh_token_request_dto.dart';
import '../dto/user_info_dto.dart';

/// Auth 远程数据源骨架。
///
/// 登录、第三方登录、刷新 token 不带 Authorization；logout/delete/session 依赖当前
/// session token，使用 required。真实 refresh 队列和 secure storage 不在本轮实现。
class AuthRemoteDataSource {
  const AuthRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AuthSessionDto> loginDevice(LoginRequestDto request) async {
    print('[AuthRemoteDataSource] loginDevice request:');
    print('[AuthRemoteDataSource]   URL: POST /api/user/device/login');
    print('[AuthRemoteDataSource]   Body: ${request.toJson()}');
    
    try {
      final result = await _apiClient.post<AuthSessionDto>(
        '/api/user/device/login',  // ← 改为正确的路径
        data: request.toJson(),
        authPolicy: ApiAuthPolicy.none,
        decoder: AuthSessionDto.fromJson,
      );
      
      print('[AuthRemoteDataSource] loginDevice response:');
      print('[AuthRemoteDataSource]   isAuthenticated: ${result.isAuthenticated}');
      print('[AuthRemoteDataSource]   isNewUser: ${result.isNewUser}');
      print('[AuthRemoteDataSource]   user: ${result.user?.userId}');
      print('[AuthRemoteDataSource]   token: ${result.token?.accessToken?.substring(0, 20)}...');
      
      return result;
    } catch (e) {
      print('[AuthRemoteDataSource] loginDevice error: $e');
      rethrow;
    }
  }

  Future<AuthSessionDto> loginOAuth(OAuthLoginRequestDto request) {
    print('[AuthRemoteDataSource] loginOAuth request:');
    print('[AuthRemoteDataSource]   URL: POST /api/user/facebook/login');
    print('[AuthRemoteDataSource]   Body: ${request.toJson()}');
    
    return _apiClient.post<AuthSessionDto>(
      '/api/user/facebook/login',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: AuthSessionDto.fromJson,
    );
  }

  Future<AuthTokenDto> refreshToken(RefreshTokenRequestDto request) {
    return _apiClient.post<AuthTokenDto>(
      '/api/user/token/refresh',
      data: request.toJson(),
      authPolicy: ApiAuthPolicy.none,
      options: Options(extra: {apiSkipAuthRefreshExtraKey: true}),
      decoder: AuthTokenDto.fromJson,
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

  Future<UserInfoDto> getUserInfo() {
    return _apiClient.get<UserInfoDto>(
      '/api/user/get',
      authPolicy: ApiAuthPolicy.required,
      decoder: UserInfoDto.fromJson,
    );
  }
}
