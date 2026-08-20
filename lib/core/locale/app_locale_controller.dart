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
    debugPrint(
      '[AppLocale] build: initial=${languageCodeFromLocale(localeForLanguageCode(defaultLanguageCode))}',
    );
    unawaited(_restoreSavedLocale());
    return localeForLanguageCode(defaultLanguageCode);
  }

  void select(Locale locale) {
    final languageCode = languageCodeFromLocale(locale);
    debugPrint('[AppLocale] select: languageCode=$languageCode');
    state = localeForLanguageCode(languageCode);
    unawaited(_saveAndLoadLanguage(languageCode));
  }

  Future<void> selectAndSave(Locale locale) async {
    final languageCode = languageCodeFromLocale(locale);
    debugPrint('[AppLocale] selectAndSave: languageCode=$languageCode');
    state = localeForLanguageCode(languageCode);
    await _saveAndLoadLanguage(languageCode);
  }

  Future<void> _restoreSavedLocale() async {
    final languageCode = await readSavedLanguageCode();
    final currentLanguageCode = languageCodeFromLocale(state);
    debugPrint(
      '[AppLocale] restore: saved=$languageCode, current=$currentLanguageCode',
    );
    if (languageCode != currentLanguageCode) {
      debugPrint('[AppLocale] restore: applying saved=$languageCode');
      state = localeForLanguageCode(languageCode);
    } else {
      debugPrint('[AppLocale] restore: no state change');
    }
  }

  Future<void> _saveAndLoadLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, languageCode);
      debugPrint('[AppLocale] save: languageCode=$languageCode');
    } catch (_) {
      debugPrint('[AppLocale] save: failed for languageCode=$languageCode');
      // Keep the in-memory locale even if local persistence is unavailable.
    }
  }

  static Future<String> readSavedLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return canonicalLanguageCode(prefs.getString(preferenceKey));
    } catch (_) {
      return defaultLanguageCode;
    }
  }

  /// 将服务端 language value 规范为 BCP-47 风格，同时保留其语言含义。
  static String canonicalLanguageCode(String? languageCode) {
    final parts = languageCode
        ?.trim()
        .replaceAll('_', '-')
        .split('-')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts == null || parts.isEmpty) return defaultLanguageCode;
    return parts
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final part = entry.value;
          if (index == 0) return part.toLowerCase();
          if (part.length == 4) {
            return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
          }
          if (part.length == 2 || part.length == 3) return part.toUpperCase();
          return part;
        })
        .join('-');
  }

  static Locale localeForLanguageCode(String languageCode) {
    final parts = canonicalLanguageCode(languageCode).split('-');
    final language = parts.first;
    String? scriptCode;
    String? countryCode;
    for (final part in parts.skip(1)) {
      if (part.length == 4 && scriptCode == null) {
        scriptCode = part;
      } else if ((part.length == 2 || part.length == 3) &&
          countryCode == null) {
        countryCode = part;
      }
    }
    return Locale.fromSubtags(
      languageCode: language,
      scriptCode: scriptCode,
      countryCode: countryCode,
    );
  }

  static String languageCodeFromLocale(Locale locale) {
    return [
      locale.languageCode,
      if (locale.scriptCode != null && locale.scriptCode!.isNotEmpty)
        locale.scriptCode!,
      if (locale.countryCode != null && locale.countryCode!.isNotEmpty)
        locale.countryCode!,
    ].join('-');
  }
}
