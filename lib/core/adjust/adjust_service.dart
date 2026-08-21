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
  static final _sessionConfirmed = Completer<void>();
  static final _eventResults = StreamController<AdjustEventResult>.broadcast();

  final String _configuredAppToken;
  final AppEnvironment _environment;
  final AdjustDeviceIdentifierReporter? _deviceIdentifierReporter;
  final AdjustDeeplinkDispatcher? _deferredDeeplinkDispatcher;

  /// Adjust 已回调会话请求成功。这个回调仅用于诊断，不能作为事件派发前置条件：
  /// 已存在的原生 session 在一次新的 Flutter 进程中不一定会再次产生该回调。
  bool get isSessionConfirmed => _sessionConfirmed.isCompleted;

  Future<void> get sessionConfirmed => _sessionConfirmed.future;

  Stream<AdjustEventResult> get eventResults => _eventResults.stream;

  /// 初始化 Android Adjust SDK。
  ///
  /// `prod` 构建使用 Production；`dev` 和 `staging` 测试构建使用 Sandbox。
  /// Token 为空时安全跳过初始化，避免发送到错误的 Adjust App。
  void initialize() {
    try {
      if (_initializationRequested) {
        if (kDebugMode) {
          debugPrint(
            '[Adjust] SDK initialization already requested; '
            'sessionConfirmed=$isSessionConfirmed.',
          );
        }
        return;
      }
      if (defaultTargetPlatform != TargetPlatform.android) return;

      if (_configuredAppToken.trim().isEmpty) {
        debugPrint('[Adjust] Initialization skipped: missing app token.');
        return;
      }

      final config = AdjustConfig(_configuredAppToken, _adjustEnvironment);
      // 保留本地补发使用的 deduplicationId，避免原生已接收但 Flutter 尚未来得及
      // 收到 success 回调时发生重复计数。
      config.eventDeduplicationIdsMaxSize = 100;
      _configureDeferredDeeplink(config);
      _configureAttributionLogging(config);
      _configureDeliveryCallbacks(config);
      Adjust.initSdk(config);
      _initializationRequested = true;
      if (kDebugMode) {
        debugPrint(
          '[Adjust] SDK initialization requested: '
          'environment=${_adjustEnvironment.name}, '
          'sessionConfirmed=$isSessionConfirmed.',
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

  void _configureDeliveryCallbacks(AdjustConfig config) {
    if (kDebugMode) config.logLevel = AdjustLogLevel.verbose;
    config.sessionSuccessCallback = (session) {
      if (!_sessionConfirmed.isCompleted) {
        _sessionConfirmed.complete();
      }
      if (kDebugMode) {
        debugPrint(
          '[Adjust] Session delivery succeeded: '
          'message=${session.message}, adid=${session.adid}, '
          'timestamp=${session.timestamp}.',
        );
      }
    };
    config.sessionFailureCallback = (session) {
      debugPrint(
        '[Adjust] Session delivery failed: message=${session.message}, '
        'willRetry=${session.willRetry}.',
      );
    };
    config.eventSuccessCallback = (event) {
      debugPrint(
        '[Adjust] Native event success: callbackId=${event.callbackId}.',
      );
      _eventResults.add(
        AdjustEventResult.success(callbackId: event.callbackId),
      );
    };
    config.eventFailureCallback = (event) {
      debugPrint(
        '[Adjust] Native event failure: callbackId=${event.callbackId}, '
        'willRetry=${event.willRetry}.',
      );
      _eventResults.add(
        AdjustEventResult.failure(
          callbackId: event.callbackId,
          willRetry: event.willRetry == true,
        ),
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

/// 原生 Adjust 对单个事件的最终回调。只有 success 才能安全清掉本地兜底记录。
class AdjustEventResult {
  const AdjustEventResult._({
    required this.callbackId,
    required this.isSuccess,
    required this.willRetry,
  });

  const AdjustEventResult.success({required String? callbackId})
    : this._(callbackId: callbackId, isSuccess: true, willRetry: false);

  const AdjustEventResult.failure({
    required String? callbackId,
    required bool willRetry,
  }) : this._(callbackId: callbackId, isSuccess: false, willRetry: willRetry);

  final String? callbackId;
  final bool isSuccess;
  final bool willRetry;
}
