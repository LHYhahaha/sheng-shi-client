import 'app_modal_controller.dart';
import 'app_modal_policy.dart';
import 'app_modal_request.dart';
import 'app_modal_result.dart';
import 'app_modal_source.dart';

/// 全局阻塞式弹窗唯一业务入口。
///
/// 瞬态反馈仍使用 [AppToastService]；需要 await 结果的业务弹窗走本服务。
abstract class AppModalService {
  Future<ConfirmResult> showConfirm(ConfirmModalRequest request);

  Future<AppModalResult> show(AppModalRequest request);

  void dismissCurrent({AppModalResult? result});

  void dismissByRequestId(String requestId, {AppModalResult? result});

  void dismissForSource(AppModalSource source, {AppModalResult? result});
}

/// 默认实现：委托 [AppModalController] 由 [AppModalHost] 展示。
class AppModalServiceImpl implements AppModalService {
  AppModalServiceImpl(this._controller);

  final AppModalController _controller;

  @override
  Future<ConfirmResult> showConfirm(ConfirmModalRequest request) async {
    final result = await _controller.present(request);
    return _asConfirmResult(result);
  }

  @override
  Future<AppModalResult> show(AppModalRequest request) {
    return _controller.present(request);
  }

  @override
  void dismissCurrent({AppModalResult? result}) {
    _controller.dismissCurrent(result: result ?? ConfirmResult.dismissed);
  }

  @override
  void dismissByRequestId(String requestId, {AppModalResult? result}) {
    _controller.dismissByRequestId(
      requestId,
      result: result ?? ConfirmResult.dismissed,
    );
  }

  @override
  void dismissForSource(AppModalSource source, {AppModalResult? result}) {
    _controller.dismissForSource(
      source,
      result: result ?? ConfirmResult.dismissed,
    );
  }

  ConfirmResult _asConfirmResult(AppModalResult result) {
    if (result is ConfirmResult) {
      return result;
    }
    return switch (result.kind) {
      AppModalResultKind.completed => ConfirmResult.confirmed,
      AppModalResultKind.cancelled => ConfirmResult.cancelled,
      AppModalResultKind.dismissed => ConfirmResult.dismissed,
      AppModalResultKind.failed => ConfirmResult.dismissed,
    };
  }
}

/// 便捷构造确认弹窗请求。
ConfirmModalRequest buildConfirmModalRequest({
  required AppModalController controller,
  required AppModalSource source,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  AppModalPriority priority = AppModalPriority.normal,
  AppModalDismissPolicy dismissPolicy = AppModalDismissPolicy.standard,
  String? requestId,
}) {
  return ConfirmModalRequest(
    requestId: requestId ?? controller.nextRequestId(),
    source: source,
    priority: priority,
    dismissPolicy: dismissPolicy,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
  );
}
