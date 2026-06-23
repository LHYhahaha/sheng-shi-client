import 'dart:convert';
import 'dart:io';

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

  Future<void> _updateRemoteStrings(LanguagePackage package) async {
    final strings = await _loadRemoteStrings(package);
    AppLocalizations.setRemoteStrings(strings);
    if (strings != null) {
      print('[I18n] Remote strings updated, ${strings.length} keys loaded');
    }
  }

  Future<void> initialize(String languageCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final service = await ref.read(i18nServiceProvider.future);
      final package = await service.initialize(languageCode);
      await _updateRemoteStrings(package);
      state = state.copyWith(
        languageCode: languageCode,
        package: package,
        isLoading: false,
      );
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
    } catch (e) {
      AppLocalizations.setRemoteStrings(null);
      state = I18nState(
        languageCode: languageCode,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> checkForUpdates(String languageCode) async {
    final service = await ref.read(i18nServiceProvider.future);
    return service.needsUpdate(languageCode);
  }

  Future<void> clearCache() async {
    final service = await ref.read(i18nServiceProvider.future);
    await service.clearCache();
    AppLocalizations.setRemoteStrings(null);
    state = const I18nState();
  }
}

final i18nControllerProvider = NotifierProvider<I18nController, I18nState>(
  I18nController.new,
);
