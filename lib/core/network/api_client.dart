import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import 'api_exception.dart';
import 'api_request_context.dart';

/// API 鉴权策略。
///
/// 登录、第三方登录、刷新 token 必须显式使用 none；登录后的业务接口使用 required。
/// 当前 skeleton 不强制 token 存在，避免破坏 mock 和远程骨架测试。
enum ApiAuthPolicy {
  /// 不带 Authorization。
  none,

  /// 如果 request context 有 token，则带 `Authorization: Bearer <token>`。
  required,
}

/// API client 的最小网络入口。
///
/// 这里集中 Dio 配置、headers 和异常映射。feature/UI 不应直接 new Dio；否则
/// token、requestId、重试和错误码策略会散落到业务层，后续接真实接口很难统一治理。
class ApiClient {
  ApiClient({
    Dio? dio,
    ApiRequestContext requestContext = const ApiRequestContext.mock(),
  }) : _dio = dio ?? Dio(_defaultOptions),
       _requestContext = requestContext {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.addAll(_requestContext.toBaseHeaders());

          if (_hasJsonBody(options)) {
            options.headers.putIfAbsent(
              Headers.contentTypeHeader,
              () => Headers.jsonContentType,
            );
          }

          final authPolicy = _authPolicyFromOptions(options);
          final token = _requestContext.accessToken;
          if (authPolicy == ApiAuthPolicy.required &&
              token != null &&
              token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
      ),
    );
  }

  /// 底层 Dio 实例。
  ///
  /// 暴露 getter 只用于底层扩展和测试；feature 层优先使用 ApiClient 的 get/post/put/delete。
  final Dio _dio;
  final ApiRequestContext _requestContext;

  Dio get dio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ApiAuthPolicy authPolicy = ApiAuthPolicy.none,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _optionsWithAuthPolicy(options, authPolicy),
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
    ApiAuthPolicy authPolicy = ApiAuthPolicy.none,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.post<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _optionsWithAuthPolicy(options, authPolicy),
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
    ApiAuthPolicy authPolicy = ApiAuthPolicy.none,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.put<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _optionsWithAuthPolicy(options, authPolicy),
      ),
      decoder: decoder,
    );
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ApiAuthPolicy authPolicy = ApiAuthPolicy.none,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.patch<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _optionsWithAuthPolicy(options, authPolicy),
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
    ApiAuthPolicy authPolicy = ApiAuthPolicy.none,
    required T Function(Object? data) decoder,
  }) {
    return _request(
      () => _dio.delete<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: _optionsWithAuthPolicy(options, authPolicy),
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
    final isSuccess = code == 0 || code == '0';
    if (isSuccess) {
      return body['data'];
    }

    throw ApiException(
      code: ApiErrorCode.badResponse,
      businessCode: _businessCodeFromEnvelope(body),
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

  Options _optionsWithAuthPolicy(Options? options, ApiAuthPolicy authPolicy) {
    final mergedExtra = <String, dynamic>{
      ...?options?.extra,
      _authPolicyExtraKey: authPolicy.name,
    };
    return (options ?? Options()).copyWith(extra: mergedExtra);
  }

  ApiAuthPolicy _authPolicyFromOptions(RequestOptions options) {
    final value = options.extra[_authPolicyExtraKey];
    if (value == ApiAuthPolicy.required.name) {
      return ApiAuthPolicy.required;
    }
    return ApiAuthPolicy.none;
  }

  bool _hasJsonBody(RequestOptions options) {
    return options.data != null &&
        options.data is! FormData &&
        options.contentType != Headers.formUrlEncodedContentType;
  }

  int? _businessCodeFromEnvelope(Map<String, Object?> body) {
    final code = body['code'];
    if (code is int) {
      return code;
    }
    if (code is num) {
      return code.toInt();
    }
    if (code is String) {
      return int.tryParse(code);
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

  static const _authPolicyExtraKey = 'apiAuthPolicy';
}
