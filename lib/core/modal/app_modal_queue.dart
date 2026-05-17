import 'dart:async';

import 'app_modal_request.dart';
import 'app_modal_result.dart';
import 'app_modal_source.dart';

/// 队列中的一条待展示弹窗（请求 + 完成器）。
class AppModalQueueEntry {
  AppModalQueueEntry({required this.request, required this.completer});

  final AppModalRequest request;
  final Completer<AppModalResult> completer;
}

/// 全局弹窗 pending 队列：按 priority 降序、同 priority 按 createdAt 升序。
class AppModalQueue {
  final List<AppModalQueueEntry> _pending = [];

  List<AppModalRequest> get pendingRequests =>
      _pending.map((entry) => entry.request).toList(growable: false);

  int get length => _pending.length;

  bool get isEmpty => _pending.isEmpty;

  bool get isNotEmpty => _pending.isNotEmpty;

  /// 按优先级插入；不抢占 current（由 [AppModalController] 控制）。
  void insert(AppModalQueueEntry entry) {
    final index = _insertIndex(entry.request);
    _pending.insert(index, entry);
  }

  AppModalQueueEntry? dequeue() {
    if (_pending.isEmpty) {
      return null;
    }
    return _pending.removeAt(0);
  }

  void clear() {
    _pending.clear();
  }

  bool containsRequestId(String requestId) {
    return _pending.any((entry) => entry.request.requestId == requestId);
  }

  /// 移除并返回被移除的条目（用于 dismiss API 完成 completer）。
  List<AppModalQueueEntry> removeByRequestId(String requestId) {
    return _removeWhere((entry) => entry.request.requestId == requestId);
  }

  List<AppModalQueueEntry> removeBySource(AppModalSource source) {
    return _removeWhere((entry) => entry.request.source == source);
  }

  List<AppModalQueueEntry> _removeWhere(
    bool Function(AppModalQueueEntry) test,
  ) {
    final removed = <AppModalQueueEntry>[];
    _pending.removeWhere((entry) {
      if (test(entry)) {
        removed.add(entry);
        return true;
      }
      return false;
    });
    return removed;
  }

  int _insertIndex(AppModalRequest request) {
    for (var i = 0; i < _pending.length; i += 1) {
      if (_compare(request, _pending[i].request) < 0) {
        return i;
      }
    }
    return _pending.length;
  }

  /// 负数表示 [a] 应排在 [b] 之前（更高优先级或更早 createdAt）。
  static int _compare(AppModalRequest a, AppModalRequest b) {
    final priorityOrder = b.priority.index.compareTo(a.priority.index);
    if (priorityOrder != 0) {
      return priorityOrder;
    }
    return a.createdAt.compareTo(b.createdAt);
  }
}
