import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale/app_locale_controller.dart';

/// 当前 API 支持的 `Lang` header 取值（内容/接口语言，与 UI 固定文案包可不同）。
const apiSupportedLangCodes = <String>{'en', 'es', 'pt', 'hi'};

/// 将 [Locale] 映射为 API `Lang`；不支持的语言 fallback 到 `en`。
///
/// UI 仍可使用 zh 等 [AppLocalizations] 语言；远程语言包阶段可替换来源 provider，
/// 但 header 仍应只经 [apiLangProvider] 注入。
String apiLangFromLocale(Locale locale) {
  final code = locale.languageCode.toLowerCase();
  if (apiSupportedLangCodes.contains(code)) {
    return code;
  }
  return 'en';
}

final apiLangProvider = Provider<String>((ref) {
  return apiLangFromLocale(ref.watch(appLocaleControllerProvider));
});
