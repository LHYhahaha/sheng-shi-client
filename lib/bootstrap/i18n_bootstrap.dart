import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/i18n.dart';
import '../features/auth/application/auth_controller.dart';

/// I18n 初始化提供者
/// 
/// 在App启动时触发语言包初始化
/// 注意：等待 token 初始化完成后再进行 i18n 初始化，因为 i18n 接口需要认证
final i18nInitializerProvider = FutureProvider<void>((ref) async {
  try {
    // 首先等待 token 初始化完成
    await ref.watch(guestLoginInitializerProvider.future);
    
    // Token 初始化完成后，触发 i18n 控制器初始化
    // I18nController 会在 build() 中自动初始化语言包
    ref.watch(i18nControllerProvider);
    
    print('[I18n] ✅ Language package initialization triggered');
  } catch (e) {
    print('[I18n] ⚠️ I18n initialization encountered an error: $e');
    // 不抛出异常，允许App继续运行
  }
});
