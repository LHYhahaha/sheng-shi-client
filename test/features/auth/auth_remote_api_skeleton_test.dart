import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/data/dto/auth_session_dto.dart';
import 'package:drama_client/features/auth/data/dto/auth_token_dto.dart';
import 'package:drama_client/features/auth/data/dto/auth_user_dto.dart';
import 'package:drama_client/features/auth/data/dto/refresh_token_request_dto.dart';
import 'package:drama_client/features/auth/data/mapper/auth_mapper.dart';
import 'package:drama_client/features/auth/data/mock_auth_repository.dart';
import 'package:drama_client/features/auth/data/session_cleanup_auth_repository.dart';
import 'package:drama_client/features/auth/data/remote/auth_remote_data_source.dart';
import 'package:drama_client/features/auth/data/remote_auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/profile/data/dto/profile_summary_dto.dart';
import 'package:drama_client/features/profile/data/mapper/profile_mapper.dart';
import 'package:drama_client/features/profile/data/mock_profile_repository.dart';
import 'package:drama_client/features/profile/data/profile_repository_provider.dart';
import 'package:drama_client/features/profile/data/remote/profile_remote_data_source.dart';
import 'package:drama_client/features/profile/data/remote_profile_repository.dart';
import 'package:drama_client/shared/media/media_resource.dart';

void main() {
  group('auth remote skeleton', () {
    test('auth user dto maps remote avatar without exposing token to UI', () {
      final dto = AuthUserDto.fromJson(_authUserJson);
      final user = const AuthMapper().mapUser(dto);

      expect(dto.userId, 'user-1');
      expect(dto.provider, 'google');
      expect(user.id, 'user-1');
      expect(user.nickname, 'Google User');
      expect(user.provider, AuthProviderType.google);
      expect(user.avatarAssetPath, authDefaultAvatarAssetPath);
      expect(user.avatarResource?.type, MediaResourceType.network);
      expect(user.avatarResource?.value, 'https://cdn.example.com/avatar.jpg');
    });

    test('auth token dto preserves raw token contract in data layer', () {
      final dto = AuthTokenDto.fromJson(_authTokenJson);

      expect(dto.accessToken, 'access-token');
      expect(dto.refreshToken, 'refresh-token');
      expect(dto.tokenType, 'Bearer');
      expect(dto.expiresAt, DateTime.parse('2026-05-15T10:00:00Z'));
      expect(dto.refreshExpiresAt, DateTime.parse('2026-06-15T10:00:00Z'));
    });

    test('auth session dto maps to existing AuthSession domain', () {
      final dto = AuthSessionDto.fromJson(_authSessionJson);
      final session = const AuthMapper().mapSession(dto);

      expect(dto.isAuthenticated, isTrue);
      expect(dto.isNewUser, isFalse);
      expect(dto.token?.accessToken, 'access-token');
      expect(session.isLoggedIn, isTrue);
      expect(session.user?.id, 'user-1');
      expect(session.user?.avatarResource?.isNetwork, isTrue);
    });

    test('google login response accepts string token expiry timestamps', () {
      final dto = AuthSessionDto.fromJson({
        'accessToken': 'google-access-token',
        'refreshToken': 'google-refresh-token',
        'accessExpireAt': '1785826791',
        'refreshExpireAt': '1787813991',
      });

      expect(dto.isAuthenticated, isTrue);
      expect(dto.token?.accessToken, 'google-access-token');
      expect(
        dto.token?.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1785826791 * 1000),
      );
    });

    test('guest session maps to guest; malformed payload fails fast', () {
      final mapper = const AuthMapper();

      expect(
        mapper
            .mapSession(AuthSessionDto.fromJson(_guestSessionJson))
            .isLoggedIn,
        isFalse,
      );
      expect(
        () => AuthSessionDto.fromJson('malformed'),
        throwsA(isA<ApiMappingException>()),
      );
    });

    test(
      'device login uses public auth policy and request context fields',
      () async {
        final adapter = _FakeHttpClientAdapter(
          responseData: _ok(_authSessionJson),
        );
        final repository = RemoteAuthRepository(
          remoteDataSource: AuthRemoteDataSource(
            apiClient: _apiClient(adapter),
          ),
          requestContext: _requestContext,
        );

        final session = await repository.login(AuthProviderType.device);

        expect(session.isLoggedIn, isTrue);
        expect(adapter.lastOptions?.method, 'POST');
        expect(adapter.lastOptions?.path, '/auth/login/device');
        expect(adapter.lastOptions?.headers['Authorization'], isNull);
        expect(adapter.lastOptions?.headers['Device-Id'], 'device');
        expect(adapter.lastOptions?.data, containsPair('deviceId', 'device'));
        expect(adapter.lastOptions?.data, containsPair('platform', 'android'));
        expect(adapter.lastOptions?.data, containsPair('appVersion', '1.0.0'));
        expect(adapter.lastOptions?.data, containsPair('lang', 'en'));
      },
    );

    test('oauth login uses current auth token and provider payload', () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: _ok(_authSessionJson),
      );
      final repository = RemoteAuthRepository(
        remoteDataSource: AuthRemoteDataSource(apiClient: _apiClient(adapter)),
        requestContext: _requestContext,
      );

      await repository.login(AuthProviderType.google);

      expect(adapter.lastOptions?.path, '/api/user/google/login');
      expect(
        adapter.lastOptions?.headers['Authorization'],
        'Bearer test-token',
      );
      expect(
        adapter.lastOptions?.data,
        containsPair('googleToken', 'mock-google-id-token'),
      );
    });

    test('device login does not request user info during startup', () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: _ok({
          'accessToken': 'access-token-long-enough-for-startup',
          'refreshToken': 'refresh-token-long-enough-for-startup',
          'accessExpireAt': 1787295267,
          'refreshExpireAt': 1789282467,
        }),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repository = RemoteAuthRepository(
        remoteDataSource: AuthRemoteDataSource(apiClient: _apiClient(adapter)),
        requestContext: _requestContext,
        tokenStore: container.read(authTokenStoreProvider.notifier),
        userInfoStore: container.read(userInfoStoreProvider.notifier),
      );

      await repository.login(AuthProviderType.device);

      expect(adapter.requests.map((request) => request.path), [
        '/api/user/device/login',
      ]);
    });

    test('session synchronization does not request user info', () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: {'code': 0, 'message': 'success', 'data': null},
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repository = RemoteAuthRepository(
        remoteDataSource: AuthRemoteDataSource(apiClient: _apiClient(adapter)),
        requestContext: _requestContext,
        userInfoStore: container.read(userInfoStoreProvider.notifier),
      );

      final session = await repository.syncCurrentSession();

      expect(session.isGuest, isTrue);
      expect(adapter.requests, isEmpty);
    });

    test('refresh token uses public auth policy', () async {
      final adapter = _FakeHttpClientAdapter(responseData: _ok(_authTokenJson));
      final source = AuthRemoteDataSource(apiClient: _apiClient(adapter));

      final token = await source.refreshToken(
        const RefreshTokenRequestDto(refreshToken: 'refresh-token'),
      );

      expect(token.accessToken, 'access-token');
      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.path, '/api/user/token/refresh');
      expect(adapter.lastOptions?.headers['Authorization'], isNull);
    });

    test('logout and delete account use required auth policy', () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: _ok({'success': true, 'isCurrentDeviceAccount': true}),
      );
      final source = AuthRemoteDataSource(apiClient: _apiClient(adapter));

      await source.logout();
      await source.deleteAccount();

      expect(adapter.requests.map((request) => request.path), [
        '/api/user/logout',
        '/api/user/delete',
      ]);
      expect(
        adapter.requests.every(
          (request) => request.headers['Authorization'] == 'Bearer test-token',
        ),
        isTrue,
      );
    });

    test('auth provider defaults to mock and can be switched to remote', () {
      final mockContainer = ProviderContainer();
      addTearDown(mockContainer.dispose);

      final mockRepository = mockContainer.read(authRepositoryProvider);
      expect(mockRepository, isA<SessionCleanupAuthRepository>());
      expect(
        (mockRepository as SessionCleanupAuthRepository).delegate,
        isA<MockAuthRepository>(),
      );

      final remoteContainer = ProviderContainer(
        overrides: [useRemoteAuthApiProvider.overrideWithValue(true)],
      );
      addTearDown(remoteContainer.dispose);

      final remoteRepository = remoteContainer.read(authRepositoryProvider);
      expect(remoteRepository, isA<SessionCleanupAuthRepository>());
      expect(
        (remoteRepository as SessionCleanupAuthRepository).delegate,
        isA<RemoteAuthRepository>(),
      );
    });

    test('profile dto maps network avatar, membership, and wallet summary', () {
      final dto = ProfileSummaryDto.fromJson(_profileJson);
      final summary = const ProfileMapper().mapSummary(dto);

      expect(summary.userId, 'user-1');
      expect(summary.displayId, 'ID:10001');
      expect(summary.avatarResource.type, MediaResourceType.network);
      expect(
        summary.avatarResource.value,
        'https://cdn.example.com/avatar.jpg',
      );
      expect(summary.membership.isActive, isTrue);
      expect(summary.wallet.coinBalance, 2000);
      expect(summary.wallet.bonusBalance, 100);
      expect(summary.language, 'en');
    });

    test(
      'profile mapper falls back to default asset when avatarUrl is missing',
      () {
        final dto = ProfileSummaryDto.fromJson({
          ..._profileJson,
          'avatarUrl': '',
        });
        final summary = const ProfileMapper().mapSummary(dto);

        expect(summary.avatarResource.type, MediaResourceType.asset);
        expect(
          summary.avatarResource.value,
          'assets/images/profile/profile_avatar_figma.png',
        );
      },
    );

    test('profile datasource uses required auth policy', () async {
      final adapter = _FakeHttpClientAdapter(responseData: _ok(_profileJson));
      final source = ProfileRemoteDataSource(apiClient: _apiClient(adapter));

      await source.getProfile();

      expect(adapter.lastOptions?.method, 'GET');
      expect(adapter.lastOptions?.path, '/profile');
      expect(
        adapter.lastOptions?.headers['Authorization'],
        'Bearer test-token',
      );
    });

    test('profile provider defaults to mock and can be switched to remote', () {
      final mockContainer = ProviderContainer();
      addTearDown(mockContainer.dispose);

      expect(
        mockContainer.read(profileRepositoryProvider),
        isA<MockProfileRepository>(),
      );

      final remoteContainer = ProviderContainer(
        overrides: [useRemoteProfileApiProvider.overrideWithValue(true)],
      );
      addTearDown(remoteContainer.dispose);

      expect(
        remoteContainer.read(profileRepositoryProvider),
        isA<RemoteProfileRepository>(),
      );
    });
  });

  test('remote DTOs stay out of application and presentation layers', () {
    final offenders = <String>[];
    final roots = [
      Directory('lib/features/auth/application'),
      Directory('lib/features/auth/presentation'),
      Directory('lib/features/profile/application'),
      Directory('lib/features/profile/presentation'),
    ];

    for (final root in roots.where((directory) => directory.existsSync())) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('/data/dto/') ||
            source.contains('/data/remote/') ||
            source.contains('remote_auth_repository.dart') ||
            source.contains('remote_profile_repository.dart')) {
          offenders.add(entity.path);
        }
      }
    }

    expect(offenders, isEmpty);
  });
}

Map<String, Object?> _ok(Object? data) => {
  'code': 0,
  'message': 'success',
  'data': data,
};

const _requestContext = ApiRequestContext(
  deviceId: 'device',
  lang: 'en',
  platform: 'android',
  appVersion: '1.0.0',
  accessToken: 'test-token',
);

ApiClient _apiClient(_FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio, requestContext: _requestContext);
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responseData});

  final Object? responseData;
  final requests = <RequestOptions>[];
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _authUserJson = {
  'userId': 'user-1',
  'nickname': 'Google User',
  'avatarUrl': 'https://cdn.example.com/avatar.jpg',
  'provider': 'google',
  'isGuest': false,
  'createdAt': '2026-05-15T09:00:00Z',
};

const _authTokenJson = {
  'accessToken': 'access-token',
  'refreshToken': 'refresh-token',
  'tokenType': 'Bearer',
  'expiresAt': '2026-05-15T10:00:00Z',
  'refreshExpiresAt': '2026-06-15T10:00:00Z',
};

const _authSessionJson = {
  'isAuthenticated': true,
  'user': _authUserJson,
  'token': _authTokenJson,
  'serverTime': '2026-05-15T09:30:00Z',
  'isNewUser': false,
};

const _guestSessionJson = {
  'isAuthenticated': false,
  'user': null,
  'token': null,
  'serverTime': '2026-05-15T09:30:00Z',
  'isNewUser': false,
};

const _profileJson = {
  'userId': 'user-1',
  'nickname': 'Google User',
  'avatarUrl': 'https://cdn.example.com/avatar.jpg',
  'displayId': 'ID:10001',
  'membershipSummary': {
    'isActive': true,
    'planId': 'weekly-vip',
    'expiresAt': '2026-06-15T10:00:00Z',
  },
  'walletSummary': {'coinBalance': 2000, 'bonusBalance': 100},
  'language': 'en',
  'region': 'PH',
  'createdAt': '2026-05-15T09:00:00Z',
};
