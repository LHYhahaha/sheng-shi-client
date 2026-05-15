import 'package:dio/dio.dart';

/// 业务层可识别的 API 错误类型。
///
/// UI 应依赖这些稳定错误码展示状态，而不是解析底层 Dio/HTTP 异常文案。
enum ApiErrorCode {
  cancelled,
  timeout,
  network,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  badResponse,
  unknown,
}

/// API 异常的统一包装。
///
/// `canRetry` 表示“可以展示重试入口”，不表示一定会自动重试。自动重试需要结合
/// 请求幂等性判断，尤其支付、消费、领奖等接口不能简单重放。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.data,
    this.cause,
    this.stackTrace,
  });

  /// 归一化错误码。
  final ApiErrorCode code;

  /// 面向开发调试的错误消息。
  ///
  /// 用户文案应由 UI 根据 code 映射，不直接展示该字段。
  final String message;

  /// HTTP 状态码。
  ///
  /// 网络超时或连接失败时可能为空。
  final int? statusCode;

  /// 后端请求 id。
  ///
  /// 用于排查接口问题，不参与业务判断。
  final String? requestId;

  /// 后端返回的错误数据。
  ///
  /// 只用于调试或结构化错误映射，UI 不应直接渲染。
  final Object? data;

  /// 原始异常。
  final Object? cause;

  /// 原始堆栈。
  final StackTrace? stackTrace;

  bool get isAuthFailure => code == ApiErrorCode.unauthorized;

  bool get canRetry {
    return switch (code) {
      ApiErrorCode.timeout ||
      ApiErrorCode.network ||
      ApiErrorCode.server ||
      ApiErrorCode.unknown => true,
      _ => false,
    };
  }

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final requestId = _requestIdFromResponse(response);

    return switch (error.type) {
      DioExceptionType.cancel => ApiException(
        code: ApiErrorCode.cancelled,
        message: 'Request cancelled.',
        statusCode: statusCode,
        requestId: requestId,
        data: response?.data,
        cause: error,
        stackTrace: error.stackTrace,
      ),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiException(
        code: ApiErrorCode.timeout,
        message: 'Network request timed out.',
        statusCode: statusCode,
        requestId: requestId,
        data: response?.data,
        cause: error,
        stackTrace: error.stackTrace,
      ),
      DioExceptionType.connectionError => ApiException(
        code: ApiErrorCode.network,
        message: 'Network connection failed.',
        statusCode: statusCode,
        requestId: requestId,
        data: response?.data,
        cause: error,
        stackTrace: error.stackTrace,
      ),
      DioExceptionType.badResponse => ApiException.fromHttpResponse(
        statusCode: statusCode,
        data: response?.data,
        requestId: requestId,
        cause: error,
        stackTrace: error.stackTrace,
      ),
      _ => ApiException(
        code: ApiErrorCode.unknown,
        message: error.message ?? 'Unknown network error.',
        statusCode: statusCode,
        requestId: requestId,
        data: response?.data,
        cause: error,
        stackTrace: error.stackTrace,
      ),
    };
  }

  factory ApiException.fromHttpResponse({
    required int? statusCode,
    Object? data,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final message = _messageFromBody(data) ?? 'Request failed.';

    return ApiException(
      code: _codeFromStatus(statusCode),
      message: message,
      statusCode: statusCode,
      requestId: requestId,
      data: data,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  static ApiErrorCode _codeFromStatus(int? statusCode) {
    if (statusCode == null) {
      return ApiErrorCode.badResponse;
    }

    return switch (statusCode) {
      401 => ApiErrorCode.unauthorized,
      403 => ApiErrorCode.forbidden,
      404 => ApiErrorCode.notFound,
      409 => ApiErrorCode.conflict,
      422 => ApiErrorCode.validation,
      >= 500 => ApiErrorCode.server,
      _ => ApiErrorCode.badResponse,
    };
  }

  static String? _messageFromBody(Object? data) {
    if (data is Map<String, Object?>) {
      final message = data['message'] ?? data['msg'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  static String? _requestIdFromResponse(Response<dynamic>? response) {
    if (response == null) {
      return null;
    }

    final fromHeader =
        response.headers.value('x-request-id') ??
        response.headers.value('x-trace-id');
    if (fromHeader != null && fromHeader.isNotEmpty) {
      return fromHeader;
    }

    final data = response.data;
    if (data is Map<String, Object?>) {
      final value = data['requestId'] ?? data['traceId'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  @override
  String toString() {
    return 'ApiException(code: $code, statusCode: $statusCode, '
        'requestId: $requestId, message: $message)';
  }
}
