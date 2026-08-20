import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale/app_locale_controller.dart';

/// 将 [Locale] 映射为 API `Lang`，保留服务端语言配置的 value。
///
/// UI 仍可使用 zh 等 [AppLocalizations] 语言；远程语言包阶段可替换来源 provider，
/// 但 header 仍应只经 [apiLangProvider] 注入。
String apiLangFromLocale(Locale locale) {
  return AppLocaleController.languageCodeFromLocale(locale);
}

final apiLangProvider = Provider<String>((ref) {
  return apiLangFromLocale(ref.watch(appLocaleControllerProvider));
});
