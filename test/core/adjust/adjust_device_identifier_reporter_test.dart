import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drama_client/core/adjust/adjust_device_identifier_reporter.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reports identifiers anonymously and omits an unavailable GPS ADID',
    () async {
      final adapter = _RecordingHttpClientAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final reporter = AdjustDeviceIdentifierReporter(
        apiClient: ApiClient(
          dio: dio,
          requestContext: const ApiRequestContext.test(
            deviceId: 'device-id',
            accessToken: 'must-not-be-sent',
          ),
        ),
      );

      await reporter.report(adjustAdid: 'adjust-adid', gpsAdid: ' ');

      expect(adapter.lastOptions?.path, '/api/user/device/adjust');
      expect(adapter.lastOptions?.method, 'POST');
      expect(adapter.lastOptions?.data, {'adjustAdid': 'adjust-adid'});
      expect(adapter.lastOptions?.headers['Device-Id'], 'device-id');
      expect(
        adapter.lastOptions?.headers.containsKey('Authorization'),
        isFalse,
      );
    },
  );
}

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'message': 'success', 'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
