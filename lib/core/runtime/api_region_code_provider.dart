import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设备地区码，用于 API `Region-Code` header。
///
/// 地区来自系统 Locale，与 App 内选择的界面语言无关。设备未设置地区时返回空字符串。
final apiRegionCodeProvider = Provider<String>((ref) {
  return apiRegionCodeFromLocale(PlatformDispatcher.instance.locale);
});

String apiRegionCodeFromLocale(Locale locale) {
  return (locale.countryCode ?? '').trim().toUpperCase();
}
