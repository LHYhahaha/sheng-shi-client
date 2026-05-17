import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_modal_controller.dart';
import 'app_modal_service.dart';

/// 全局弹窗协调器；由 [AppModalHost] 监听并展示 UI。
final appModalControllerProvider = Provider<AppModalController>((ref) {
  final controller = AppModalController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// 全局弹窗服务入口；业务层通过此 Provider 请求弹窗。
final appModalServiceProvider = Provider<AppModalService>((ref) {
  return AppModalServiceImpl(ref.watch(appModalControllerProvider));
});
