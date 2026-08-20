import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channel/channel_config_service.dart';
import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import 'app_active_device_info.dart';

typedef PushTokenReader = Future<String?> Function();

class AppActiveReporter {
  AppActiveReporter({
    required ApiClient apiClient,
    required AppActiveDeviceInfoReader deviceInfoReader,
    PushTokenReader? pushTokenReader,
    DateTime Function()? now,
    this.hotStartThreshold = const Duration(minutes: 30),
  }) : _apiClient = apiClient,
       _deviceInfoReader = deviceInfoReader,
       _pushTokenReader = pushTokenReader ?? _unavailablePushToken,
       _now = now ?? DateTime.now;

  final ApiClient _apiClient;
  final AppActiveDeviceInfoReader _deviceInfoReader;
  final PushTokenReader _pushTokenReader;
  final DateTime Function() _now;
  final Duration hotStartThreshold;

  DateTime? _backgroundedAt;
  bool _reportInFlight = false;
  bool _pendingReport = false;
  bool _pendingPushTokenReport = false;

  /// 上报一次启动/活跃状态。
  ///
  /// 首次启动会优先发一条不等待 FCM 的上报；若 FCM 在这条请求结束前拿到 token，
  /// 不能因正在请求而丢弃补报。将它合并为待执行请求，当前请求完成后再带 token
  /// 上报一次。
  Future<void> reportAppLaunch({bool includePushToken = true}) {
    _pendingReport = true;
    _pendingPushTokenReport = _pendingPushTokenReport || includePushToken;
    return _drainReports();
  }

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
      await reportAppLaunch();
    }
  }

  Future<void> _drainReports() async {
    if (_reportInFlight) {
      return;
    }
    while (_pendingReport) {
      final includePushToken = _pendingPushTokenReport;
      _pendingReport = false;
      _pendingPushTokenReport = false;
      await _reportOnce(includePushToken: includePushToken);
    }
  }

  Future<void> _reportOnce({required bool includePushToken}) async {
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
      final pushToken = includePushToken ? await _pushTokenReader() : null;
      await _apiClient.post<void>(
        '/api/user/active/report',
        authPolicy: ApiAuthPolicy.required,
        data: <String, String>{
          'channelSource': info.channelSource,
          'region': info.region,
          'timezone': info.timezone,
          if (pushToken != null && pushToken.isNotEmpty) 'pushToken': pushToken,
        },
        decoder: (_) {},
      );
    } catch (error) {
      debugPrint('[AppActiveReporter] Active report failed: $error');
    } finally {
      _reportInFlight = false;
    }
  }
}

Future<String?> _unavailablePushToken() async => null;

/// FCM 在 [main] 初始化完成后覆盖此 provider，避免活跃上报模块直接依赖 Firebase。
final pushTokenReaderProvider = Provider<PushTokenReader>((ref) {
  return _unavailablePushToken;
});

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
    pushTokenReader: ref.watch(pushTokenReaderProvider),
  );
});
