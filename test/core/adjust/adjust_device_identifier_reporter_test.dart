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
        pendingStore: _MemoryPendingStore(),
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

  test('keeps a failed report and retries it on recovery', () async {
    final pendingStore = _MemoryPendingStore();
    final failingAdapter = _RecordingHttpClientAdapter(statusCode: 500);
    final failingReporter = AdjustDeviceIdentifierReporter(
      apiClient: ApiClient(
        dio: Dio()..httpClientAdapter = failingAdapter,
        requestContext: const ApiRequestContext.test(deviceId: 'device-id'),
      ),
      pendingStore: pendingStore,
    );

    expect(
      await failingReporter.report(adjustAdid: 'adjust-adid', gpsAdid: 'gps'),
      isFalse,
    );
    expect((await pendingStore.read())?.adjustAdid, 'adjust-adid');

    final succeedingAdapter = _RecordingHttpClientAdapter();
    final succeedingReporter = AdjustDeviceIdentifierReporter(
      apiClient: ApiClient(
        dio: Dio()..httpClientAdapter = succeedingAdapter,
        requestContext: const ApiRequestContext.test(deviceId: 'device-id'),
      ),
      pendingStore: pendingStore,
    );

    expect(await succeedingReporter.recoverPending(), isTrue);
    expect(succeedingAdapter.lastOptions?.data, {
      'adjustAdid': 'adjust-adid',
      'gpsAdid': 'gps',
    });
    expect(await pendingStore.read(), isNull);
  });
}

class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter({this.statusCode = 200});

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
      jsonEncode({'code': 0, 'message': 'success', 'data': null}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryPendingStore implements AdjustDeviceIdentifierPendingStore {
  AdjustDeviceIdentifiers? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AdjustDeviceIdentifiers?> read() async => value;

  @override
  Future<void> write(AdjustDeviceIdentifiers identifiers) async {
    value = identifiers;
  }
}
