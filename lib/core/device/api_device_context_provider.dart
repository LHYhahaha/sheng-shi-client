import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API 设备/应用上下文 provider。
///
/// 当前提供可测试 fallback；真实阶段可以替换为安装 id、package info 等实现。feature
/// 不允许自己拼这些 header，否则不同接口会出现 device/lang/version 不一致。
final apiDeviceIdProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_DEVICE_ID',
    defaultValue: 'mock-device-id',
  );
});

final apiAppVersionProvider = Provider<String>((ref) {
  return const String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
});
