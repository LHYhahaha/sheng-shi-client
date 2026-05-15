import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all requests include base headers', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {
        'code': 0,
        'message': 'success',
        'data': {'ok': true},
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(
      dio: dio,
      requestContext: const ApiRequestContext(
        deviceId: 'device-1',
        lang: 'zh',
        platform: 'android',
        appVersion: '1.2.3',
      ),
    );

    await client.get<Map<String, Object?>>(
      '/home/feed',
      decoder: (data) => data! as Map<String, Object?>,
    );

    expect(adapter.lastOptions!.headers['Device-Id'], 'device-1');
    expect(adapter.lastOptions!.headers['Lang'], 'zh');
    expect(adapter.lastOptions!.headers['Platform'], 'android');
    expect(adapter.lastOptions!.headers['App-Version'], '1.2.3');
    expect(adapter.lastOptions!.headers['Accept'], 'application/json');
    expect(adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
  });

  test('json body requests include content type', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(dio: dio);

    await client.post<void>(
      '/orders',
      data: {'productId': 'coins-1'},
      decoder: (_) {},
    );

    expect(
      adapter.lastOptions!.headers[Headers.contentTypeHeader],
      Headers.jsonContentType,
    );
  });

  test('auth required adds bearer token', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(
      dio: dio,
      requestContext: const ApiRequestContext(
        deviceId: 'device-1',
        lang: 'en',
        platform: 'android',
        appVersion: '1.0.0',
        accessToken: 'token-1',
      ),
    );

    await client.get<void>(
      '/me/profile',
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );

    expect(adapter.lastOptions!.headers['Authorization'], 'Bearer token-1');
  });

  test('auth none does not add bearer token even when token exists', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(
      dio: dio,
      requestContext: const ApiRequestContext(
        deviceId: 'device-1',
        lang: 'en',
        platform: 'android',
        appVersion: '1.0.0',
        accessToken: 'token-1',
      ),
    );

    await client.post<void>('/auth/login', decoder: (_) {});

    expect(adapter.lastOptions!.headers.containsKey('Authorization'), isFalse);
  });

  test('code zero unwraps data and data null reaches decoder', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 0, 'message': 'success', 'data': null},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(dio: dio);

    final result = await client.get<String?>(
      '/nullable',
      decoder: (data) => data as String?,
    );

    expect(result, isNull);
  });

  test('code 200 is treated as business failure', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {'code': 200, 'message': 'legacy ok', 'data': null},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(dio: dio);

    final future = client.get<void>('/legacy', decoder: (_) {});

    await expectLater(
      future,
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', ApiErrorCode.badResponse)
            .having((error) => error.businessCode, 'businessCode', 200)
            .having((error) => error.message, 'message', 'legacy ok'),
      ),
    );
  });

  test('business code is preserved on envelope failure', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {
        'code': 1001,
        'message': 'invalid parameter',
        'data': null,
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(dio: dio);

    final future = client.get<void>('/bad-request', decoder: (_) {});

    await expectLater(
      future,
      throwsA(
        isA<ApiException>()
            .having((error) => error.businessCode, 'businessCode', 1001)
            .having((error) => error.message, 'message', 'invalid parameter'),
      ),
    );
  });

  test('http 401 still maps to unauthorized', () async {
    final adapter = _FakeHttpClientAdapter(
      statusCode: 401,
      responseData: {'message': 'token expired'},
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(dio: dio);

    final future = client.get<void>('/me/profile', decoder: (_) {});

    await expectLater(
      future,
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', ApiErrorCode.unauthorized)
            .having((error) => error.isAuthFailure, 'isAuthFailure', isTrue),
      ),
    );
  });
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responseData, this.statusCode = 200});

  final Object? responseData;
  final int statusCode;
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
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
