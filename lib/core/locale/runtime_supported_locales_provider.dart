import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_locale_controller.dart';

/// 本次运行中 Flutter 可识别的 Locale。
///
/// App 启动时仅提供内置语言；用户进入语言设置页后，将服务端下发的
/// BCP-47 code 注册进来，无需为每个新增语言重新发包。
final runtimeSupportedLocalesProvider =
    NotifierProvider<RuntimeSupportedLocalesController, List<Locale>>(
      RuntimeSupportedLocalesController.new,
    );

class RuntimeSupportedLocalesController extends Notifier<List<Locale>> {
  static const _builtInLocales = [Locale('en'), Locale('zh')];

  @override
  List<Locale> build() {
    unawaited(_registerSavedLocale());
    return _builtInLocales;
  }

  Future<void> _registerSavedLocale() async {
    final languageCode = await AppLocaleController.readSavedLanguageCode();
    if (!ref.mounted) {
      return;
    }
    registerLanguageCodes([languageCode]);
  }

  void registerLanguageCodes(Iterable<String> languageCodes) {
    final locales = <Locale>[...state];
    for (final code in languageCodes) {
      final locale = AppLocaleController.localeForLanguageCode(code);
      if (!locales.contains(locale)) {
        locales.add(locale);
      }
    }
    if (locales.length != state.length) {
      state = List.unmodifiable(locales);
    }
  }
}
