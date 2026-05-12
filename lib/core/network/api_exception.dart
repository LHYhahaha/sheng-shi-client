import 'package:dio/dio.dart';

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

  final ApiErrorCode code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final Object? data;
  final Object? cause;
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
