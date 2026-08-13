import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../network/api_client_provider.dart';
import 'i18n_service.dart';
import 'language_package.dart';

final i18nServiceProvider = FutureProvider<I18nService>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = await SharedPreferences.getInstance();
  return I18nService(apiClient: apiClient, prefs: prefs);
});

class I18nState {
  const I18nState({
    this.languageCode = 'en',
    this.package,
    this.isLoading = false,
    this.error,
  });

  final String languageCode;
  final LanguagePackage? package;
  final bool isLoading;
  final String? error;

  I18nState copyWith({
    String? languageCode,
    LanguagePackage? package,
    bool? isLoading,
    String? error,
  }) {
    return I18nState(
      languageCode: languageCode ?? this.languageCode,
      package: package ?? this.package,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class I18nController extends Notifier<I18nState> {
  @override
  I18nState build() => const I18nState();

  Future<Map<String, dynamic>?> _loadRemoteStrings(
    LanguagePackage package,
  ) async {
    try {
      final file = File(package.filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[I18n] Failed to load remote strings: $e');
    }
    return null;
  }

  Future<void> _updateRemoteStrings(
    LanguagePackage package, {
    bool isActiveLanguage = true,
  }) async {
    final strings = await _loadRemoteStrings(package);
    AppLocalizations.setRemoteStrings(
      strings,
      languageCode: package.languageCode,
      isActiveLanguage: isActiveLanguage,
    );
    if (strings != null) {
      print('[I18n] Remote strings updated, ${strings.length} keys loaded');
    }
  }

  Future<void> initialize(String languageCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = await ref.read(i18nServiceProvider.future);
      final cachedPackage = await service.loadCachedPackage(languageCode);
      if (cachedPackage != null) {
        await _updateRemoteStrings(cachedPackage);
        state = state.copyWith(
          languageCode: languageCode,
          package: cachedPackage,
          isLoading: false,
        );
        // 缓存已足够首屏使用；版本检查、下载与英文兜底包均移至后台。
        unawaited(_refreshStartupPackage(service, languageCode));
        unawaited(_warmDefaultLanguageStrings(service, languageCode));
        return;
      }

      final package = await service.initialize(languageCode);
      await _updateRemoteStrings(package);
      state = state.copyWith(
        languageCode: languageCode,
        package: package,
        isLoading: false,
      );
      unawaited(_warmDefaultLanguageStrings(service, languageCode));
      print('[I18n] Language package initialized successfully');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      print('[I18n] Failed to initialize language package: $e');
      rethrow;
    }
  }

  Future<void> switchLanguage(String languageCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = await ref.read(i18nServiceProvider.future);
      final package = await service.switchLanguage(languageCode);
      await _updateRemoteStrings(package);
      state = state.copyWith(
        languageCode: languageCode,
        package: package,
        isLoading: false,
      );
      // 切换语言不等待英文兜底包；缺失时继续使用当前本地文案。
      unawaited(_warmDefaultLanguageStrings(service, languageCode));
    } catch (e) {
      AppLocalizations.clearRemoteStrings();
      state = I18nState(
        languageCode: languageCode,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _refreshStartupPackage(
    I18nService service,
    String languageCode,
  ) async {
    try {
      final package = await service.initialize(languageCode);
      if (state.languageCode != languageCode) {
        return;
      }
      await _updateRemoteStrings(package);
      if (state.languageCode != languageCode) {
        return;
      }
      state = state.copyWith(package: package, isLoading: false);
    } catch (error) {
      // 缓存已生效，后台更新失败不影响当前界面。
      debugPrint('[I18n] Background package refresh failed: $error');
    }
  }

  Future<void> _warmDefaultLanguageStrings(
    I18nService service,
    String activeLanguageCode,
  ) async {
    const defaultLanguageCode = 'en';
    if (activeLanguageCode == defaultLanguageCode) {
      return;
    }
    try {
      final package = await service.initialize(defaultLanguageCode);
      await _updateRemoteStrings(package, isActiveLanguage: false);
    } catch (_) {
      // 默认语言包不可用时，动态 Tab 文案会继续降级到客户端原文案。
    }
  }

  Future<bool> checkForUpdates(String languageCode) async {
    final service = await ref.read(i18nServiceProvider.future);
    return service.needsUpdate(languageCode);
  }

  Future<void> clearCache() async {
    final service = await ref.read(i18nServiceProvider.future);
    await service.clearCache();
    AppLocalizations.clearRemoteStrings();
    state = const I18nState();
  }
}

final i18nControllerProvider = NotifierProvider<I18nController, I18nState>(
  I18nController.new,
);
