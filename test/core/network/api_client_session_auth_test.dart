import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drama_client/core/auth/api_session_auth_handler.dart';
import 'package:drama_client/core/auth/auth_refresh_coordinator.dart';
import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single 401 triggers refresh and retries once successfully', () async {
    final container = await _containerWithTokens();
    addTearDown(container.dispose);

    final adapter = _SequentialStatusAdapter(
      statuses: [401, 200],
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final client = _clientWithHandler(container, adapter);

    await client.get<void>(
      '/me/profile',
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );

    expect(adapter.callCount, 2);
    expect(
      container.read(authTokenStoreProvider).accessToken,
      'access-refreshed',
    );
  });

  test('concurrent 401 only triggers one refresh', () async {
    final container = await _containerWithTokens();
    addTearDown(container.dispose);

    final adapter = _SequentialStatusAdapter(
      statuses: [401, 401, 200, 200],
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final client = _clientWithHandler(container, adapter);

    await Future.wait([
      client.get<void>(
        '/me/profile',
        authPolicy: ApiAuthPolicy.required,
        decoder: (_) {},
      ),
      client.get<void>(
        '/wallet',
        authPolicy: ApiAuthPolicy.required,
        decoder: (_) {},
      ),
    ]);

    expect(adapter.callCount, 4);
    expect(_refreshCalls, 1);
  });

  test('refresh failure clears token and invokes session cleanup', () async {
    _refreshCalls = 0;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(
          const AuthTokenSnapshot(
            accessToken: 'old',
            refreshToken: 'refresh-1',
          ),
        );

    final cleanupReasons = <SessionCleanupReason>[];
    final sessionCleanup = container.read(sessionCleanupCoordinatorProvider);
    sessionCleanup.register((reason) async {
      cleanupReasons.add(reason);
    });

    final adapter = _SequentialStatusAdapter(
      statuses: [401],
      responseData: {'message': 'token expired'},
    );
    final client = ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      requestContextReader: () {
        final token = container.read(authTokenStoreProvider);
        return ApiRequestContext(
          deviceId: 'device',
          lang: 'en',
          platform: 'android',
          appVersion: '1.0.0',
          accessToken: token.accessToken,
        );
      },
      sessionAuthHandler: ApiSessionAuthHandler(
        refreshCoordinator: AuthRefreshCoordinator(),
        tokenStore: container.read(authTokenStoreProvider.notifier),
        readToken: () => container.read(authTokenStoreProvider),
        sessionCleanup: sessionCleanup,
        refreshExecutor: (_) async {
          _refreshCalls += 1;
          throw StateError('refresh failed');
        },
      ),
    );

    await expectLater(
      client.get<void>(
        '/me/profile',
        authPolicy: ApiAuthPolicy.required,
        decoder: (_) {},
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          ApiErrorCode.unauthorized,
        ),
      ),
    );

    expect(container.read(authTokenStoreProvider).hasAccessToken, isFalse);
    expect(cleanupReasons, [SessionCleanupReason.refreshFailed]);
    expect(adapter.callCount, 1);
  });

  test(
    'refresh endpoint uses none policy and is not blocked without token',
    () async {
      final adapter = _SequentialStatusAdapter(
        statuses: [200],
        responseData: {
          'code': 0,
          'message': 'success',
          'data': {
            'accessToken': 'new-access',
            'refreshToken': 'new-refresh',
            'tokenType': 'Bearer',
          },
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient(
        dio: dio,
        requestContextReader: () => const ApiRequestContext(
          deviceId: 'device',
          lang: 'en',
          platform: 'android',
          appVersion: '1.0.0',
        ),
      );

      await client.post<void>(
        '/auth/refresh',
        data: {'refreshToken': 'refresh-1'},
        authPolicy: ApiAuthPolicy.none,
        options: Options(extra: {apiSkipAuthRefreshExtraKey: true}),
        decoder: (_) {},
      );

      expect(adapter.callCount, 1);
      expect(
        adapter.lastOptions!.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );

  test('required auth without token does not send HTTP request', () async {
    final adapter = _SequentialStatusAdapter(
      statuses: [200],
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final client = ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      requestContextReader: () => const ApiRequestContext(
        deviceId: 'device',
        lang: 'en',
        platform: 'android',
        appVersion: '1.0.0',
      ),
    );

    await expectLater(
      client.get<void>(
        '/me/profile',
        authPolicy: ApiAuthPolicy.required,
        decoder: (_) {},
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          ApiErrorCode.sessionRequired,
        ),
      ),
    );

    expect(adapter.callCount, 0);
  });
}

var _refreshCalls = 0;

Future<ProviderContainer> _containerWithTokens() async {
  _refreshCalls = 0;
  final container = ProviderContainer();
  await container
      .read(authTokenStoreProvider.notifier)
      .save(
        const AuthTokenSnapshot(
          accessToken: 'access-old',
          refreshToken: 'refresh-1',
        ),
      );
  return container;
}

ApiClient _clientWithHandler(
  ProviderContainer container,
  _SequentialStatusAdapter adapter,
) {
  return ApiClient(
    dio: Dio()..httpClientAdapter = adapter,
    requestContextReader: () {
      final token = container.read(authTokenStoreProvider);
      return ApiRequestContext(
        deviceId: 'device',
        lang: 'en',
        platform: 'android',
        appVersion: '1.0.0',
        accessToken: token.accessToken,
      );
    },
    sessionAuthHandler: ApiSessionAuthHandler(
      refreshCoordinator: AuthRefreshCoordinator(),
      tokenStore: container.read(authTokenStoreProvider.notifier),
      readToken: () => container.read(authTokenStoreProvider),
      sessionCleanup: container.read(sessionCleanupCoordinatorProvider),
      refreshExecutor: (refreshToken) async {
        _refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return AuthTokenSnapshot(
          accessToken: 'access-refreshed',
          refreshToken: refreshToken,
        );
      },
    ),
  );
}

class _SequentialStatusAdapter implements HttpClientAdapter {
  _SequentialStatusAdapter({
    required this.statuses,
    required this.responseData,
  });

  final List<int> statuses;
  final Object? responseData;
  int callCount = 0;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final index = callCount < statuses.length ? callCount : statuses.length - 1;
    callCount += 1;
    final statusCode = statuses[index];
    return ResponseBody.fromString(
      jsonEncode(responseData),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
