import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/i18n.dart';

/// I18n 初始化提供者
///
/// 在App启动时触发语言包初始化
/// 注意：由 App 启动流程保证 token 初始化完成后再触发这里。
final i18nInitializerProvider = FutureProvider<void>((ref) async {
  try {
    // Token 初始化完成后，触发 i18n 控制器初始化。
    // I18nController 会在 build() 中自动初始化语言包
    ref.read(i18nControllerProvider);

    print('[I18n] ✅ Language package initialization triggered');
  } catch (e) {
    print('[I18n] ⚠️ I18n initialization encountered an error: $e');
    // 不抛出异常，允许App继续运行
  }
});
