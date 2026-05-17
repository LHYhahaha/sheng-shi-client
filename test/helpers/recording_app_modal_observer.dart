import 'package:drama_client/core/modal/app_modal_observer.dart';

/// 测试用弹窗诊断记录器。
class RecordingAppModalObserver extends AppModalObserver {
  final List<AppModalObserverEvent> events = [];

  @override
  void onEvent(AppModalObserverEvent event) {
    events.add(event);
  }

  void clear() => events.clear();
}
