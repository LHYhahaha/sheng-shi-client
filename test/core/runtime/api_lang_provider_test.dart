import 'package:drama_client/core/locale/app_locale_controller.dart';
import 'package:drama_client/core/runtime/api_lang_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('apiLangFromLocale', () {
    test('supports en zh', () {
      expect(apiLangFromLocale(const Locale('en')), 'en');
      expect(apiLangFromLocale(const Locale('zh')), 'zh');
    });

    test('unsupported language falls back to en', () {
      expect(apiLangFromLocale(const Locale('es')), 'en');
      expect(apiLangFromLocale(const Locale('fr')), 'en');
    });
  });

  test('apiLangProvider reflects locale and can be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(apiLangProvider), 'en');

    container
        .read(appLocaleControllerProvider.notifier)
        .select(const Locale('zh'));
    expect(container.read(apiLangProvider), 'zh');

    container
        .read(appLocaleControllerProvider.notifier)
        .select(const Locale('es'));
    expect(container.read(apiLangProvider), 'en');
  });
}
