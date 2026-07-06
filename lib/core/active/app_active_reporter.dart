import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channel/channel_config_service.dart';
import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import 'app_active_device_info.dart';

class AppActiveReporter {
  AppActiveReporter({
    required ApiClient apiClient,
    required AppActiveDeviceInfoReader deviceInfoReader,
    DateTime Function()? now,
    this.hotStartThreshold = const Duration(minutes: 30),
  }) : _apiClient = apiClient,
       _deviceInfoReader = deviceInfoReader,
       _now = now ?? DateTime.now;

  final ApiClient _apiClient;
  final AppActiveDeviceInfoReader _deviceInfoReader;
  final DateTime Function() _now;
  final Duration hotStartThreshold;

  DateTime? _backgroundedAt;
  bool _reportInFlight = false;

  Future<void> reportAppLaunch() => _report();

  Future<void> onLifecycleChanged(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= _now();
      return;
    }
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt != null &&
        _now().difference(backgroundedAt) > hotStartThreshold) {
      await _report();
    }
  }

  Future<void> _report() async {
    if (_reportInFlight) {
      return;
    }
    final accessToken = _apiClient.requestContext.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint(
        '[AppActiveReporter] Skip active report: session is unavailable.',
      );
      return;
    }
    _reportInFlight = true;
    try {
      final info = await _deviceInfoReader.read();
      await _apiClient.post<void>(
        '/api/user/active/report',
        authPolicy: ApiAuthPolicy.required,
        data: <String, String>{
          'channelSource': info.channelSource,
          'region': info.region,
          'timezone': info.timezone,
        },
        decoder: (_) {},
      );
    } catch (error, stackTrace) {
      debugPrint('[AppActiveReporter] Active report failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _reportInFlight = false;
    }
  }
}

final appActiveDeviceInfoReaderProvider = Provider<AppActiveDeviceInfoReader>((
  ref,
) {
  return PlatformAppActiveDeviceInfoReader(
    channelConfigService: ref.watch(channelConfigServiceProvider),
  );
});

final appActiveReporterProvider = Provider<AppActiveReporter>((ref) {
  return AppActiveReporter(
    apiClient: ref.watch(apiClientProvider),
    deviceInfoReader: ref.watch(appActiveDeviceInfoReaderProvider),
  );
});
