import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_api_envelope.dart';

/// 记录请求并可按 path 返回预设响应的 Dio [HttpClientAdapter]。
///
/// 用于 Home/Drama remote dry run：不启动真实 server，仍可断言 headers/path/envelope。
class RecordingHttpAdapter implements HttpClientAdapter {
  RecordingHttpAdapter({
    Map<String, RecordingHttpResponse> responses = const {},
    RecordingHttpResponse? defaultResponse,
  }) : _responses = Map<String, RecordingHttpResponse>.from(responses),
       _defaultResponse =
           defaultResponse ??
           RecordingHttpResponse(body: apiEnvelopeSuccess(null));

  final Map<String, RecordingHttpResponse> _responses;
  RecordingHttpResponse? _defaultResponse;
  DioException? fetchException;

  final List<RecordedHttpRequest> requests = [];

  void setResponse(String method, String path, RecordingHttpResponse response) {
    _responses[_key(method, path)] = response;
  }

  void setDefaultResponse(RecordingHttpResponse response) {
    _defaultResponse = response;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedHttpRequest.from(options));

    if (fetchException != null) {
      throw fetchException!;
    }

    final response =
        _responses[_key(options.method, options.path)] ?? _defaultResponse!;

    if (response.throwException != null) {
      throw response.throwException!;
    }

    final body = response.body;
    final encoded = body is String ? body : jsonEncode(body);

    return ResponseBody.fromString(
      encoded,
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close({bool force = false}) {}

  String _key(String method, String path) => '${method.toUpperCase()} $path';
}

class RecordingHttpResponse {
  const RecordingHttpResponse({
    required this.body,
    this.statusCode = 200,
    this.headers = const {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
    this.throwException,
  });

  final Object? body;
  final int statusCode;
  final Map<String, List<String>> headers;
  final DioException? throwException;
}

class RecordedHttpRequest {
  const RecordedHttpRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.queryParameters,
  });

  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> queryParameters;

  factory RecordedHttpRequest.from(RequestOptions options) {
    return RecordedHttpRequest(
      method: options.method,
      path: options.path,
      headers: Map<String, dynamic>.from(options.headers),
      queryParameters: Map<String, dynamic>.from(options.queryParameters),
    );
  }
}
