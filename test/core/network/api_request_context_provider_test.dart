import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/locale/app_locale_controller.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_client_provider.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/runtime/api_platform_provider.dart';
import 'package:drama_client/core/runtime/app_version_provider.dart';
import 'package:drama_client/core/runtime/in_memory_install_id_storage.dart';
import 'package:drama_client/core/runtime/install_id_provider.dart';

void main() {
  test(
    'request context is composed from install id, lang, platform, app version and token',
    () async {
      final storage = InMemoryInstallIdStorage();
      await storage.write('11111111-1111-4111-8111-111111111111');
      final container = ProviderContainer(
        overrides: [
          installIdStorageProvider.overrideWithValue(storage),
          apiAppVersionProvider.overrideWithValue('9.9.9'),
          apiPlatformProvider.overrideWithValue('ios'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(installIdProvider.future);
      container
          .read(appLocaleControllerProvider.notifier)
          .select(const Locale('zh'));
      await container
          .read(authTokenStoreProvider.notifier)
          .save(const AuthTokenSnapshot(accessToken: 'token-1'));

      final context = container.read(apiRequestContextProvider);

      expect(context.deviceId, '11111111-1111-4111-8111-111111111111');
      expect(context.lang, 'zh');
      expect(context.platform, 'ios');
      expect(context.appVersion, '9.9.9');
      expect(context.accessToken, 'token-1');
    },
  );

  test('unsupported locale maps lang to en in request context', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(appLocaleControllerProvider.notifier)
        .select(const Locale('es'));

    expect(container.read(apiRequestContextProvider).lang, 'en');
  });

  test('none requests include base headers from request context', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final storage = InMemoryInstallIdStorage();
    await storage.write('22222222-2222-4222-8222-222222222222');
    final container = ProviderContainer(
      overrides: [
        installIdStorageProvider.overrideWithValue(storage),
        installIdProvider.overrideWith(
          (ref) async => '22222222-2222-4222-8222-222222222222',
        ),
        apiAppVersionProvider.overrideWithValue('3.0.0'),
        apiPlatformProvider.overrideWithValue('android'),
        apiClientProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          return ApiClient(
            dio: dio,
            requestContextReader: () => ref.read(apiRequestContextProvider),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(installIdProvider.future);
    container
        .read(appLocaleControllerProvider.notifier)
        .select(const Locale('zh'));

    await container
        .read(apiClientProvider)
        .get<void>(
          '/api/user/token/refresh',
          authPolicy: ApiAuthPolicy.none,
          decoder: (_) {},
        );

    expect(
      adapter.lastOptions?.headers['Device-Id'],
      '22222222-2222-4222-8222-222222222222',
    );
    expect(adapter.lastOptions?.headers['Lang'], 'zh');
    expect(adapter.lastOptions?.headers['Platform'], 'android');
    expect(adapter.lastOptions?.headers['App-Version'], '3.0.0');
    expect(adapter.lastOptions?.headers.containsKey('Authorization'), isFalse);
  });

  test('auth required request can use access token from token store', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final container = ProviderContainer(
      overrides: [
        installIdProvider.overrideWith(
          (ref) async => '33333333-3333-4333-8333-333333333333',
        ),
        apiAppVersionProvider.overrideWithValue('1.0.0'),
        apiPlatformProvider.overrideWithValue('web'),
      ],
    );
    addTearDown(container.dispose);

    await container.read(installIdProvider.future);
    // 先创建 client，再保存 token，覆盖设备登录完成后立即请求用户信息的真实时序。
    final client = container.read(apiClientProvider)
      ..dio.httpClientAdapter = adapter;
    await container
        .read(authTokenStoreProvider.notifier)
        .save(const AuthTokenSnapshot(accessToken: 'token-from-store'));

    await client.get<void>(
      '/profile',
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );

    expect(
      adapter.lastOptions?.headers['Authorization'],
      'Bearer token-from-store',
    );
    expect(adapter.lastOptions?.headers['Device-Id'], isNotEmpty);
    expect(adapter.lastOptions?.headers['Lang'], isNotEmpty);
    expect(adapter.lastOptions?.headers['Platform'], 'web');
    expect(adapter.lastOptions?.headers['App-Version'], '1.0.0');
  });

  test('auth required request without token fails fast locally', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final container = ProviderContainer(
      overrides: [
        installIdProvider.overrideWith(
          (ref) async => '44444444-4444-4444-8444-444444444444',
        ),
        apiClientProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          return ApiClient(
            dio: dio,
            requestContextReader: () => ref.read(apiRequestContextProvider),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(installIdProvider.future);

    await expectLater(
      container
          .read(apiClientProvider)
          .get<void>(
            '/profile',
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

    expect(adapter.lastOptions, isNull);
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responseData});

  final Object? responseData;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
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
