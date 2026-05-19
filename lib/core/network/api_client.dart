import 'package:dio/dio.dart';

import '../config/app_environment.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio(_defaultOptions);

  final Dio _dio;

  Dio get dio => _dio;

  static BaseOptions get _defaultOptions {
    return BaseOptions(
      baseUrl: AppConfig.current.apiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    );
  }
}
