import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../auth/api_session_auth_handler.dart';
import '../config/app_environment.dart';
import 'api_exception.dart';
import 'api_request_context.dart';

/// API 鉴权策略（当前阶段仅 [none] 与 [required]；游客/正式细分见文档）。
///
/// 阶段性语义（Post-RC Track A）：
/// - [none]：完全公开接口，不带 Authorization（含 guest bootstrap、login/link、refresh）。
/// - [required]：需要 **任意有效 session access token**（游客 token 或正式用户 token
///   均可），缺失时 fail-fast 抛 [ApiErrorCode.sessionRequired]，不发起 HTTP。
///
/// 不等于"必须正式登录用户"。未来可能扩展（文档先行，enum 暂不增以免破坏 skeleton）：
/// - `guestOrUser`：游客或正式 token 均可（与当前 required 接近）。
/// - `userRequired`：必须正式账号 token（会员/钱包/片单等）。
/// - refresh 专用策略继续配合 [apiSkipAuthRefreshExtraKey]。
enum ApiAuthPolicy { none, required }

typedef ApiRequestContextReader = ApiRequestContext Function();
typedef ApiChannelHeadersReader = FutureOr<Map<String, String>> Function();

/// API client 的网络入口。
///
/// - 统一 header、envelope、401 refresh（单飞 + 重试一次）、required 空 token 拦截。
/// - feature/UI 不应直接 new Dio。
class ApiClient {
  ApiClient({
    Dio? dio,
    ApiRequestContext? requestContext,
    ApiRequestContextReader? requestContextReader,
    ApiChannelHeadersReader? channelHeadersReader,
    ApiSessionAuthHandler? sessionAuthHandler,
  }) : _dio = dio ?? Dio(defaultOptions),
       _requestContextReader =
           requestContextReader ??
           (() => requestContext ?? const ApiRequestContext.test()),
       _channelHeadersReader =
           channelHeadersReader ?? (() => const <String, String>{}),
       _sessionAuthHandler = sessionAuthHandler {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final context = _readRequestContext();

          // 验证 deviceId 是否有效，拒绝使用 fallback 值发送请求
          _validateDeviceId(context.deviceId, options, handler);

          options.headers.addAll(context.toBaseHeaders());
          options.headers.addAll(await _channelHeadersReader());

          if (_hasJsonBody(options)) {
            options.headers.putIfAbsent(
              Headers.contentTypeHeader,
              () => Headers.jsonContentType,
            );
          }

          final authPolicy = _authPolicyFromOptions(options);
          if (authPolicy == ApiAuthPolicy.required) {
            final token = context.accessToken;
            if (token == null || token.isEmpty) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.unknown,
                  error: ApiException.sessionRequired(path: options.path),
                ),
              );
              return;
            }
            options.headers['Authorization'] = 'Bearer $token';
          } else if (!options.headers.containsKey('Authorization')) {
            // Only remove Authorization header if it wasn't explicitly set
            options.headers.remove('Authorization');
          }

          // 打印完整的请求URL和详细信息
          final fullUrl = '${options.baseUrl}${options.path}';
          print('[ApiClient] ========== REQUEST ==========');
          print('[ApiClient] Full URL: ${options.method} $fullUrl');
          print('[ApiClient] Base URL: ${options.baseUrl}');
          print('[ApiClient] Path: ${options.path}');
          print('[ApiClient] Headers: ${options.headers}');
          if (options.data != null) {
            print('[ApiClient] Body: ${options.data}');
          }
          print('[ApiClient] Body queryParameters: ${options.queryParameters}');

          print('[ApiClient] ==============================');

          handler.next(options);
        },
        onResponse: (response, handler) {
          final fullUrl =
              '${response.requestOptions.baseUrl}${response.requestOptions.path}';
          print('[ApiClient] ========== RESPONSE ==========');
          print(
            '[ApiClient] Full URL: ${response.requestOptions.method} $fullUrl',
          );
          print('[ApiClient] Status Code: ${response.statusCode}');
          print('[ApiClient] Data: ${response.data}');
          print('[ApiClient] ==============================');
          handler.next(response);
        },
        onError: (error, handler) {
          final fullUrl =
              '${error.requestOptions.baseUrl}${error.requestOptions.path}';
          print('[ApiClient] ========== ERROR ==========');
          print(
            '[ApiClient] Full URL: ${error.requestOptions.method} $fullUrl',
          );
          print('[ApiClient] Status Code: ${error.response?.statusCode}');
          print('[ApiClient] Error: ${error.message}');
          print('[ApiClient] ==============================');
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final ApiRequestContextReader _requestContextReader;
  final ApiChannelHeadersReader _channelHeadersReader;
  ApiSessionAuthHandler? _sessionAuthHandler;

  Dio get dio => _dio;

  /// 获取当前的请求上下文
  ApiRequestContext get requestContext => _readRequestContext();

  /// 设置 session auth handler（用于打破循环依赖）
  void setSessionAuthHandler(ApiSessionAuthHandler handler) {
    _sessionAuthHandler = handler;
  }

  ApiRequestContext _readRequestContext() => _requestContextReader();

  /// 验证 deviceId 是否有效，拒绝使用 fallback 值发送请求
  void _validateDeviceId(
    String deviceId,
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // 检查是否使用了 fallback 值
    if (deviceId == 'install-id-pending') {
      debugPrint(
        '[ApiClient] ❌ Device-Id validation failed: using fallback value "$deviceId". '
        'Request to ${options.path} will be rejected.',
      );
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError(
            'Device-Id not ready. Request rejected to prevent using invalid Device-Id. '
            'Value: "$deviceId". Ensure installIdProvider is loaded before making API calls.',
          ),
        ),
      );
      return;
    }

    // 验证是否为有效的 UUID 格式（简单检查）
    if (!_isValidUuid(deviceId) && deviceId != 'test-install-id') {
      debugPrint(
        '[ApiClient] ⚠️ Device-Id might be invalid: "$deviceId". '
        'Expected UUID format. Request to ${options.path} will proceed but may cause issues.',
      );
    }
  }

  /// 简单的 UUID 格式验证（UUID v4: 8-4-4-4-12 十六进制字符）
  bool _isValidUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(value);
  }

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
      authPolicy: authPolicy,
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
      authPolicy: authPolicy,
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
      authPolicy: authPolicy,
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
      authPolicy: authPolicy,
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
      authPolicy: authPolicy,
      decoder: decoder,
    );
  }

  Future<T> _request<T>(
    Future<Response<Object?>> Function() send, {
    required ApiAuthPolicy authPolicy,
    required T Function(Object? data) decoder,
  }) async {
    var hasRetriedAfterRefresh = false;

    while (true) {
      try {
        final response = await send();
        return _decode(response, decoder);
      } on ApiException catch (error) {
        if (await _recoverFromSessionExpiredBusinessCode(error)) {
          rethrow;
        }
        if (await _recoverFromSessionInvalidated(error)) {
          rethrow;
        }
        if (await _recoverFromUnauthorized(
          error,
          hasRetriedAfterRefresh,
          authPolicy,
          null,
        )) {
          hasRetriedAfterRefresh = true;
          continue;
        }
        rethrow;
      } on DioException catch (error) {
        final apiError = error.error is ApiException
            ? error.error! as ApiException
            : ApiException.fromDio(error);
        if (await _recoverFromSessionExpiredBusinessCode(apiError)) {
          throw apiError;
        }
        if (await _recoverFromSessionInvalidated(apiError)) {
          throw apiError;
        }
        if (await _recoverFromUnauthorized(
          apiError,
          hasRetriedAfterRefresh,
          authPolicy,
          error.requestOptions,
        )) {
          hasRetriedAfterRefresh = true;
          continue;
        }
        throw apiError;
      } catch (error, stackTrace) {
        debugPrint('[ApiClient] 未知错误: $error');
        debugPrint('[ApiClient] 错误类型: ${error.runtimeType}');
        debugPrint('[ApiClient] 堆栈: $stackTrace');

        throw ApiException(
          code: ApiErrorCode.unknown,
          message: 'Unexpected client error.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// 401 时尝试 refresh；成功返回 true 以便外层重试原请求一次。
  Future<bool> _recoverFromSessionExpiredBusinessCode(
    ApiException error,
  ) async {
    if (error.businessCode != _guestSessionExpiredBusinessCode ||
        _sessionAuthHandler == null) {
      return false;
    }

    return _sessionAuthHandler!.handleSessionExpiredBusinessCode();
  }

  Future<bool> _recoverFromSessionInvalidated(ApiException error) async {
    if (error.businessCode != _sessionInvalidatedBusinessCode ||
        _sessionAuthHandler == null) {
      return false;
    }

    await _sessionAuthHandler!.handleSessionInvalidated();
    return true;
  }

  Future<bool> _recoverFromUnauthorized(
    ApiException error,
    bool hasRetriedAfterRefresh,
    ApiAuthPolicy authPolicy,
    RequestOptions? requestOptions,
  ) async {
    if (!_shouldAttemptRefresh(
      error,
      hasRetriedAfterRefresh,
      authPolicy,
      requestOptions,
    )) {
      return false;
    }

    final recovered = await _sessionAuthHandler!.handleUnauthorized();
    if (recovered) {
      return true;
    }

    throw ApiException(
      code: ApiErrorCode.unauthorized,
      message: 'Session expired.',
      statusCode: error.statusCode,
      requestId: error.requestId,
      cause: error,
    );
  }

  bool _shouldAttemptRefresh(
    ApiException error,
    bool hasRetriedAfterRefresh,
    ApiAuthPolicy authPolicy,
    RequestOptions? requestOptions,
  ) {
    if (_sessionAuthHandler == null) {
      return false;
    }
    if (authPolicy != ApiAuthPolicy.required) {
      return false;
    }
    if (hasRetriedAfterRefresh) {
      return false;
    }
    if (error.isSessionRequired) {
      return false;
    }
    // 防止 refresh 请求本身再次触发 refresh（避免循环）
    if (requestOptions?.extra[apiSkipAuthRefreshExtraKey] == true) {
      return false;
    }
    return error.code == ApiErrorCode.unauthorized;
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

  static BaseOptions get defaultOptions {
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
  static const _guestSessionExpiredBusinessCode = 1006;
  static const _sessionInvalidatedBusinessCode = 1007;
}

/// 标记 refresh 请求，避免 refresh 自身 401 时再次进入 refresh 死循环。
const String apiSkipAuthRefreshExtraKey = 'apiSkipAuthRefresh';
