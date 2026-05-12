import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps timeout dio error to retryable api exception', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/dramas'),
      type: DioExceptionType.connectionTimeout,
    );

    final exception = ApiException.fromDio(error);

    expect(exception.code, ApiErrorCode.timeout);
    expect(exception.canRetry, isTrue);
  });

  test('maps unauthorized response to auth failure', () {
    final exception = ApiException.fromHttpResponse(
      statusCode: 401,
      data: {'message': 'token expired'},
      requestId: 'req-1',
    );

    expect(exception.code, ApiErrorCode.unauthorized);
    expect(exception.isAuthFailure, isTrue);
    expect(exception.message, 'token expired');
    expect(exception.requestId, 'req-1');
  });
}
