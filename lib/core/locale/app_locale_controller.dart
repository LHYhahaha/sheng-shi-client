import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLocaleControllerProvider =
    NotifierProvider<AppLocaleController, Locale>(AppLocaleController.new);

class AppLocaleController extends Notifier<Locale> {
  static const preferenceKey = 'app_locale_language_code';
  static const defaultLanguageCode = 'en';

  @override
  Locale build() {
    unawaited(_restoreSavedLocale());
    return const Locale(defaultLanguageCode);
  }

  void select(Locale locale) {
    final languageCode = normalizeLanguageCode(locale.languageCode);
    state = Locale(languageCode);
    unawaited(_saveAndLoadLanguage(languageCode));
  }

  Future<void> selectAndSave(Locale locale) async {
    final languageCode = normalizeLanguageCode(locale.languageCode);
    state = Locale(languageCode);
    await _saveAndLoadLanguage(languageCode);
  }

  Future<void> _restoreSavedLocale() async {
    final languageCode = await readSavedLanguageCode();
    if (languageCode != state.languageCode) {
      state = Locale(languageCode);
    }
  }

  Future<void> _saveAndLoadLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, languageCode);
    } catch (_) {
      // Keep the in-memory locale even if local persistence is unavailable.
    }
  }

  static Future<String> readSavedLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return normalizeLanguageCode(prefs.getString(preferenceKey));
    } catch (_) {
      return defaultLanguageCode;
    }
  }

  static String normalizeLanguageCode(String? languageCode) {
    final normalized = languageCode?.toLowerCase();
    return switch (normalized) {
      'zh' || 'zh_cn' || 'zh-cn' || 'zh_hans' || 'zh-hans' => 'zh',
      _ => defaultLanguageCode,
    };
  }
}
