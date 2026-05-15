import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/device/api_device_context_provider.dart';
import 'package:drama_client/core/locale/app_locale_controller.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_client_provider.dart';

void main() {
  test(
    'request context is composed from device, locale, app version and token',
    () async {
      final container = ProviderContainer(
        overrides: [
          apiDeviceIdProvider.overrideWithValue('device-realistic'),
          apiAppVersionProvider.overrideWithValue('9.9.9'),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(appLocaleControllerProvider.notifier)
          .select(const Locale('zh'));
      await container
          .read(authTokenStoreProvider.notifier)
          .save(const AuthTokenSnapshot(accessToken: 'token-1'));

      final context = container.read(apiRequestContextProvider);

      expect(context.deviceId, 'device-realistic');
      expect(context.lang, 'zh');
      expect(context.appVersion, '9.9.9');
      expect(context.accessToken, 'token-1');
    },
  );

  test('lang changes are reflected in request context', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(apiRequestContextProvider).lang, 'en');

    container
        .read(appLocaleControllerProvider.notifier)
        .select(const Locale('zh'));

    expect(container.read(apiRequestContextProvider).lang, 'zh');
  });

  test('auth required request can use access token from token store', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          return ApiClient(
            dio: dio,
            requestContext: ref.watch(apiRequestContextProvider),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

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
  });

  test(
    'auth required request without token keeps current non-blocking behavior',
    () async {
      final adapter = _FakeHttpClientAdapter(
        responseData: {'code': 0, 'message': 'success', 'data': null},
      );
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWith((ref) {
            final dio = Dio()..httpClientAdapter = adapter;
            return ApiClient(
              dio: dio,
              requestContext: ref.watch(apiRequestContextProvider),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(apiClientProvider)
          .get<void>(
            '/profile',
            authPolicy: ApiAuthPolicy.required,
            decoder: (_) {},
          );

      expect(
        adapter.lastOptions?.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );
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
