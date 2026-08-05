import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_modal_controller.dart';
import 'app_modal_analytics_tracker.dart';
import 'app_modal_observer.dart';
import 'app_modal_presenter_registry.dart';
import 'app_modal_runtime_config.dart';
import 'app_modal_service.dart';
import 'presenters/confirm_app_modal_presenter.dart';
import '../analytics/analytics_provider.dart';

/// 弹窗诊断观察者；测试可 override 为 [RecordingAppModalObserver]。
final appModalObserverProvider = Provider<AppModalObserver>(
  (ref) => const NoOpAppModalObserver(),
);

/// 弹窗运行时配置；测试可 override [maxQueueLength] / [enableModalDiagnostics]。
final appModalRuntimeConfigProvider = Provider<AppModalRuntimeConfig>(
  (ref) => AppModalRuntimeConfig.defaults,
);

/// 全局弹窗协调器；由 [AppModalHost] 监听并展示 UI。
final appModalControllerProvider = Provider<AppModalController>((ref) {
  final controller = AppModalController(
    observer: ref.watch(appModalObserverProvider),
    runtimeConfig: ref.watch(appModalRuntimeConfigProvider),
    analyticsTracker: AppModalAnalyticsTracker(
      ref.read(analyticsServiceProvider),
    ),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// 全局弹窗服务入口；业务层通过此 Provider 请求弹窗。
final appModalServiceProvider = Provider<AppModalService>((ref) {
  return AppModalServiceImpl(ref.watch(appModalControllerProvider));
});

/// 默认仅含 confirm；[main] 通过 override 注入 Player 等 presenter。
final appModalPresenterRegistryProvider = Provider<AppModalPresenterRegistry>((
  ref,
) {
  return AppModalPresenterRegistry([ConfirmAppModalPresenter()]);
});
