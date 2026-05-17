import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// API `Platform` header 来源；feature 不得手写 platform 字符串。
final apiPlatformProvider = Provider<String>((ref) => resolveApiPlatform());

/// 解析运行平台：android / ios / web；桌面 debug 返回 macos/windows/linux。
String resolveApiPlatform() {
  if (kIsWeb) {
    return 'web';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
