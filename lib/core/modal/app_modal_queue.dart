import 'app_modal_request.dart';

/// 全局弹窗队列协调器骨架（O5 实现抢占、去重与互斥组）。
class AppModalQueue {
  final List<AppModalRequest> _pending = [];

  List<AppModalRequest> get pending => List.unmodifiable(_pending);

  bool get isEmpty => _pending.isEmpty;

  /// 入队；当前 O1 仅记录，实际展示由 [AppModalController] 串行处理。
  void enqueue(AppModalRequest request) {
    _pending.add(request);
  }

  /// 出队下一个请求；无待处理时返回 null。
  AppModalRequest? dequeue() {
    if (_pending.isEmpty) {
      return null;
    }
    return _pending.removeAt(0);
  }

  void clear() => _pending.clear();

  void removeByRequestId(String requestId) {
    _pending.removeWhere((request) => request.requestId == requestId);
  }

  /// O5：按 requestId 去重。
  bool containsRequestId(String requestId) {
    return _pending.any((request) => request.requestId == requestId);
  }
}
