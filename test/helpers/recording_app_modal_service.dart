import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_service.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';

/// 测试用弹窗记录器：不展示 UI，记录请求并返回预设结果。
class RecordingAppModalService implements AppModalService {
  final List<AppModalRequest> requests = [];
  final Map<String, AppModalResult> presetResultsByRequestId = {};

  ConfirmResult defaultConfirmResult = ConfirmResult.confirmed;
  AppModalResult defaultGenericResult = ConfirmResult.dismissed;
  final List<AppModalSource> dismissForSourceCalls = [];
  int dismissAllBlockingBusinessModalsCalls = 0;

  @override
  Future<ConfirmResult> showConfirm(ConfirmModalRequest request) async {
    requests.add(request);
    return _resolveConfirm(request.requestId);
  }

  @override
  Future<AppModalResult> show(AppModalRequest request) async {
    requests.add(request);
    return presetResultsByRequestId[request.requestId] ?? defaultGenericResult;
  }

  @override
  void dismissCurrent({AppModalResult? result}) {}

  @override
  void dismissByRequestId(String requestId, {AppModalResult? result}) {}

  @override
  void dismissForSource(AppModalSource source, {AppModalResult? result}) {
    dismissForSourceCalls.add(source);
  }

  @override
  void dismissAllBlockingBusinessModals({AppModalResult? result}) {
    dismissAllBlockingBusinessModalsCalls += 1;
    for (final source in [
      AppModalSource.player,
      AppModalSource.store,
      AppModalSource.membership,
      AppModalSource.auth,
    ]) {
      dismissForSource(source, result: result);
    }
    dismissCurrent(result: result);
  }

  ConfirmResult _resolveConfirm(String requestId) {
    final preset = presetResultsByRequestId[requestId];
    if (preset is ConfirmResult) {
      return preset;
    }
    if (preset != null) {
      return switch (preset.kind) {
        AppModalResultKind.completed => ConfirmResult.confirmed,
        AppModalResultKind.cancelled => ConfirmResult.cancelled,
        AppModalResultKind.dismissed => ConfirmResult.dismissed,
        AppModalResultKind.failed => ConfirmResult.dismissed,
      };
    }
    return defaultConfirmResult;
  }

  void clear() {
    requests.clear();
    presetResultsByRequestId.clear();
    defaultConfirmResult = ConfirmResult.confirmed;
    defaultGenericResult = ConfirmResult.dismissed;
    dismissForSourceCalls.clear();
    dismissAllBlockingBusinessModalsCalls = 0;
  }
}
