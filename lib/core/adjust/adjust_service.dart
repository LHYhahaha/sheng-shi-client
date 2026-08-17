import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_config.dart';
import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import 'adjust_device_identifier_reporter.dart';
import 'adjust_deeplink_dispatcher.dart';

/// NovaShort 的 Adjust 初始化边界。
///
/// 仅负责创建 SDK 会话和归因；事件、用户标识、深链和回调由后续需求接入，
/// 不应分散在业务页面中直接调用 Adjust SDK。
class AdjustService {
  AdjustService({
    String appToken = _novaShortAppToken,
    AppEnvironment? environment,
    AdjustDeviceIdentifierReporter? deviceIdentifierReporter,
    void Function(Uri deeplink)? onDeferredDeeplink,
  }) : _configuredAppToken = appToken,
       _environment = environment ?? AppConfig.current.environment,
       _deviceIdentifierReporter = deviceIdentifierReporter,
       _deferredDeeplinkDispatcher = onDeferredDeeplink == null
           ? null
           : AdjustDeeplinkDispatcher(onDeferredDeeplink);

  /// NovaShort 在 Adjust 后台登记的应用识别码。
  static const _novaShortAppToken = 'i3xfcgiqzsao';
  static bool _initializationRequested = false;

  final String _configuredAppToken;
  final AppEnvironment _environment;
  final AdjustDeviceIdentifierReporter? _deviceIdentifierReporter;
  final AdjustDeeplinkDispatcher? _deferredDeeplinkDispatcher;

  /// 初始化 Android Adjust SDK。
  ///
  /// `prod` 构建使用 Production；`dev` 和 `staging` 测试构建使用 Sandbox。
  /// Token 为空时安全跳过初始化，避免发送到错误的 Adjust App。
  void initialize() {
    try {
      if (_initializationRequested) return;
      if (defaultTargetPlatform != TargetPlatform.android) return;

      if (_configuredAppToken.trim().isEmpty) {
        debugPrint('[Adjust] Initialization skipped: missing app token.');
        return;
      }

      final config = AdjustConfig(_configuredAppToken, _adjustEnvironment);
      _configureDeferredDeeplink(config);
      _configureAttributionLogging(config);
      if (kDebugMode) {
        _configureDebugLogging(config);
      }
      Adjust.initSdk(config);
      _initializationRequested = true;
      if (kDebugMode) {
        debugPrint(
          '[Adjust] SDK initialization requested: '
          'environment=${_adjustEnvironment.name}.',
        );
      }
      unawaited(_readAndReportDeviceIdentifiers());
    } catch (error, stackTrace) {
      debugPrint('[Adjust] Initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  AdjustEnvironment get _adjustEnvironment => switch (_environment) {
    AppEnvironment.prod => AdjustEnvironment.production,
    AppEnvironment.dev || AppEnvironment.staging => AdjustEnvironment.sandbox,
  };

  void _configureDebugLogging(AdjustConfig config) {
    config.logLevel = AdjustLogLevel.verbose;
    config.sessionSuccessCallback = (session) {
      debugPrint(
        '[Adjust] Session success: '
        'message=${session.message}, adid=${session.adid}, '
        'timestamp=${session.timestamp}.',
      );
    };
  }

  /// 延迟深链不会再次触发系统 Scheme；由 Flutter 统一转交现有路由流程。
  void _configureDeferredDeeplink(AdjustConfig config) {
    config.isDeferredDeeplinkOpeningEnabled = false;
    config.deferredDeeplinkCallback = (deeplink) {
      debugPrint('[Adjust] Deferred deeplink: $deeplink');
      final dispatched =
          _deferredDeeplinkDispatcher?.dispatch(deeplink) ?? false;
      if (!dispatched && deeplink?.trim().isNotEmpty == true) {
        debugPrint('[Adjust] Deferred deeplink ignored: $deeplink');
      }
    };
  }

  /// Adjust 在首次归因和归因变化时都会回调。
  ///
  /// 不只在 Debug 注册，以便正式包联调时也能从设备日志确认广告来源。
  void _configureAttributionLogging(AdjustConfig config) {
    config.attributionCallback = (attribution) {
      debugPrint(
        '[Adjust] Attribution: '
        'tracker=${attribution.trackerToken}, '
        'network=${attribution.network}, '
        'campaign=${attribution.campaign}, '
        'adgroup=${attribution.adgroup}, '
        'creative=${attribution.creative}.',
      );
    };
  }

  Future<void> _readAndReportDeviceIdentifiers() async {
    try {
      final adid = await Adjust.getAdidWithTimeout(5000);
      final googleAdId = await Adjust.getGoogleAdId().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (kDebugMode) {
        debugPrint(
          '[Adjust] Device identifiers: '
          'adjust_adid=${adid ?? '<unavailable>'}, '
          'gps_adid=${googleAdId ?? '<unavailable>'}.',
        );
      }
      if (adid == null || adid.trim().isEmpty) return;
      await _deviceIdentifierReporter?.report(
        adjustAdid: adid,
        gpsAdid: googleAdId,
      );
    } catch (error, stackTrace) {
      debugPrint('[Adjust] Failed to read device identifiers: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
