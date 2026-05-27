import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client_provider.dart';
import 'i18n_service.dart';
import 'language_package.dart';

/// I18n 服务提供者
final i18nServiceProvider = FutureProvider<I18nService>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = await SharedPreferences.getInstance();
  return I18nService(apiClient: apiClient, prefs: prefs);
});

/// 当前语言包状态
class I18nState {
  final String languageCode;
  final LanguagePackage? package;
  final bool isLoading;
  final String? error;

  const I18nState({
    this.languageCode = 'en',
    this.package,
    this.isLoading = false,
    this.error,
  });

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

/// I18n 控制器
class I18nController extends Notifier<I18nState> {
  late I18nService _service;
  bool _initialized = false;

  @override
  I18nState build() {
    final serviceAsync = ref.watch(i18nServiceProvider);
    serviceAsync.whenData((service) {
      _service = service;
      // 自动初始化语言包（仅在首次构建时）
      if (!_initialized && state.package == null && !state.isLoading) {
        _initialized = true;
        Future.microtask(() => _initializeLanguage());
      }
    });
    return const I18nState();
  }

  /// 内部初始化方法
  Future<void> _initializeLanguage() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final package = await _service.initialize('zh');
      state = state.copyWith(
        languageCode: 'zh',
        package: package,
        isLoading: false,
      );
      print('[I18n] ✅ Language package initialized successfully');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      print('[I18n] ❌ Failed to initialize language package: $e');
    }
  }

  /// 初始化语言包
  Future<void> initialize(String languageCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final package = await _service.initialize(languageCode);
      state = state.copyWith(
        languageCode: languageCode,
        package: package,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// 切换语言
  Future<void> switchLanguage(String languageCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final package = await _service.switchLanguage(languageCode);
      state = state.copyWith(
        languageCode: languageCode,
        package: package,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// 检查更新
  Future<bool> checkForUpdates(String languageCode) async {
    return await _service.needsUpdate(languageCode);
  }

  /// 清空缓存
  Future<void> clearCache() async {
    await _service.clearCache();
    state = const I18nState();
  }
}

/// I18n 控制器提供者
final i18nControllerProvider = NotifierProvider<I18nController, I18nState>(
  I18nController.new,
);
