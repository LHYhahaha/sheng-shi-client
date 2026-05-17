import 'app_modal_policy.dart';
import 'app_modal_request.dart';
import 'app_modal_result.dart';
import 'app_modal_source.dart';

/// 弹窗生命周期事件类型（O5 诊断；非 analytics SDK）。
enum AppModalObserverEventKind {
  queued,
  presented,
  completed,
  dismissed,
  cancelled,
  replaced,
  failedToPresent,
  queueRejected,
}

/// 单次弹窗诊断事件。
class AppModalObserverEvent {
  const AppModalObserverEvent({
    required this.kind,
    required this.requestId,
    required this.source,
    required this.type,
    required this.priority,
    this.channel,
    this.resultKind,
    this.elapsedMs,
    this.rejectReason,
  });

  final AppModalObserverEventKind kind;
  final String requestId;
  final AppModalSource source;
  final AppModalType type;
  final AppModalPriority priority;
  final String? channel;
  final AppModalResultKind? resultKind;
  final int? elapsedMs;
  final String? rejectReason;
}

/// 弹窗诊断回调；默认 [NoOpAppModalObserver]。
abstract class AppModalObserver {
  const AppModalObserver();

  void onEvent(AppModalObserverEvent event);
}

class NoOpAppModalObserver extends AppModalObserver {
  const NoOpAppModalObserver();

  @override
  void onEvent(AppModalObserverEvent event) {}
}

String? appModalChannelFor(AppModalRequest request) {
  if (request is FeatureAppModalRequest) {
    return request.channel;
  }
  return null;
}
