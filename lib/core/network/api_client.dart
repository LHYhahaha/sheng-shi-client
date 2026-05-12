import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio(_defaultOptions) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.putIfAbsent('Accept', () => 'application/json');
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Dio get dio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      decoder: decoder,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.post<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      decoder: decoder,
    );
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.put<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      decoder: decoder,
    );
  }

  Future<T> delete<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.delete<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
      ),
      decoder: decoder,
    );
  }

  Future<T> _request<T>(
    Future<Response<Object?>> Function() request, {
    required T Function(Object? data) decoder,
  }) async {
    try {
      final response = await request();
      return _decode(response, decoder);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } catch (error, stackTrace) {
      throw ApiException(
        code: ApiErrorCode.unknown,
        message: 'Unexpected client error.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  T _decode<T>(Response<Object?> response, T Function(Object? data) decoder) {
    final statusCode = response.statusCode;
    if (statusCode == null || statusCode < 200 || statusCode >= 300) {
      throw ApiException.fromHttpResponse(
        statusCode: statusCode,
        data: response.data,
        requestId: _requestIdFromResponse(response),
      );
    }

    final body = response.data;
    final payload = _extractEnvelopePayload(body);
    return decoder(payload);
  }

  Object? _extractEnvelopePayload(Object? body) {
    if (body is! Map<String, Object?>) {
      return body;
    }

    if (!body.containsKey('code') || !body.containsKey('data')) {
      return body;
    }

    final code = body['code'];
    final isSuccess = code == 0 || code == '0' || code == 200 || code == '200';
    if (isSuccess) {
      return body['data'];
    }

    throw ApiException(
      code: ApiErrorCode.badResponse,
      message: _messageFromEnvelope(body) ?? 'Request failed.',
      requestId: _requestIdFromEnvelope(body),
      data: body,
    );
  }

  String? _messageFromEnvelope(Map<String, Object?> body) {
    final value = body['message'] ?? body['msg'] ?? body['error'];
    return value is String && value.isNotEmpty ? value : null;
  }

  String? _requestIdFromEnvelope(Map<String, Object?> body) {
    final value = body['requestId'] ?? body['traceId'];
    return value is String && value.isNotEmpty ? value : null;
  }

  String? _requestIdFromResponse(Response<Object?> response) {
    final fromHeader =
        response.headers.value('x-request-id') ??
        response.headers.value('x-trace-id');
    if (fromHeader != null && fromHeader.isNotEmpty) {
      return fromHeader;
    }

    final body = response.data;
    if (body is Map<String, Object?>) {
      return _requestIdFromEnvelope(body);
    }

    return null;
  }

  static BaseOptions get _defaultOptions {
    return BaseOptions(
      baseUrl: AppConfig.current.apiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    );
  }
}
