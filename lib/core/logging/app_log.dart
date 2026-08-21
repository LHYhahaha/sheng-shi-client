import 'dart:async';
import 'dart:developer' as developer;

import '../config/app_environment.dart';

/// 应用开发日志的统一出口。
///
/// `APP_ENV=prod` 的安装包不输出 Dart 层日志；开发与 staging 环境保持现有日志，
/// 方便排查问题。错误上报和业务埋点不使用此入口，不受影响。
void log(
  String message, {
  DateTime? time,
  int sequenceNumber = 0,
  int level = 0,
  String name = '',
  Zone? zone,
  Object? error,
  StackTrace? stackTrace,
}) {
  if (AppConfig.current.isProduction) {
    return;
  }
  developer.log(
    message,
    time: time,
    sequenceNumber: sequenceNumber,
    level: level,
    name: name,
    zone: zone,
    error: error,
    stackTrace: stackTrace,
  );
}
