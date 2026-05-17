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
      await storage.write('device-realistic');
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
          .select(const Locale('es'));
      await container
          .read(authTokenStoreProvider.notifier)
          .save(const AuthTokenSnapshot(accessToken: 'token-1'));

      final context = container.read(apiRequestContextProvider);

      expect(context.deviceId, 'device-realistic');
      expect(context.lang, 'es');
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
        .select(const Locale('zh'));

    expect(container.read(apiRequestContextProvider).lang, 'en');
  });

  test('none requests include base headers from request context', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final storage = InMemoryInstallIdStorage();
    await storage.write('install-abc');
    final container = ProviderContainer(
      overrides: [
        installIdStorageProvider.overrideWithValue(storage),
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
        .select(const Locale('pt'));

    await container
        .read(apiClientProvider)
        .get<void>(
          '/auth/refresh',
          authPolicy: ApiAuthPolicy.none,
          decoder: (_) {},
        );

    expect(adapter.lastOptions?.headers['Device-Id'], 'install-abc');
    expect(adapter.lastOptions?.headers['Lang'], 'pt');
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
        installIdStorageProvider.overrideWithValue(InMemoryInstallIdStorage()),
        apiAppVersionProvider.overrideWithValue('1.0.0'),
        apiPlatformProvider.overrideWithValue('web'),
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
    await container
        .read(authTokenStoreProvider.notifier)
        .save(const AuthTokenSnapshot(accessToken: 'token-from-store'));

    await container
        .read(apiClientProvider)
        .get<void>(
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
        installIdStorageProvider.overrideWithValue(InMemoryInstallIdStorage()),
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
