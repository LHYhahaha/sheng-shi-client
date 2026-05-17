import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_modal_queue.dart';
import 'app_modal_request.dart';
import 'app_modal_result.dart';
import 'app_modal_source.dart';

/// 当前正在展示的弹窗会话。
class AppModalPresentation {
  AppModalPresentation({required this.request, required this.completer});

  final AppModalRequest request;
  final Completer<AppModalResult> completer;
}

class _PendingModal {
  _PendingModal({required this.request, required this.completer});

  final AppModalRequest request;
  final Completer<AppModalResult> completer;
}

/// Host 与 Service 之间的协调器；O1 串行展示，队列骨架已接入。
class AppModalController extends ChangeNotifier {
  AppModalController({AppModalQueue? queue})
    : _queue = queue ?? AppModalQueue();

  final AppModalQueue _queue;
  final List<_PendingModal> _pending = [];

  AppModalPresentation? _current;
  int _requestCounter = 0;

  AppModalQueue get queue => _queue;

  AppModalPresentation? get current => _current;

  bool get hasCurrent => _current != null;

  String nextRequestId() {
    _requestCounter += 1;
    return 'app_modal_$_requestCounter';
  }

  Future<AppModalResult> present(AppModalRequest request) {
    final completer = Completer<AppModalResult>();
    final pending = _PendingModal(request: request, completer: completer);

    if (_current == null) {
      _activate(pending);
    } else {
      _pending.add(pending);
      _queue.enqueue(request);
    }

    return completer.future;
  }

  void _activate(_PendingModal pending) {
    _current = AppModalPresentation(
      request: pending.request,
      completer: pending.completer,
    );
    notifyListeners();
  }

  void completeCurrent(AppModalResult result) {
    final presentation = _current;
    if (presentation == null) {
      return;
    }
    if (!presentation.completer.isCompleted) {
      presentation.completer.complete(result);
    }
    _current = null;
    notifyListeners();
    _activateNext();
  }

  void dismissCurrent({AppModalResult result = ConfirmResult.dismissed}) {
    completeCurrent(result);
  }

  void dismissForSource(
    AppModalSource source, {
    AppModalResult result = ConfirmResult.dismissed,
  }) {
    if (_current?.request.source == source) {
      dismissCurrent(result: result);
    }
    _pending.removeWhere((pending) {
      if (pending.request.source == source) {
        if (!pending.completer.isCompleted) {
          pending.completer.complete(result);
        }
        _queue.removeByRequestId(pending.request.requestId);
        return true;
      }
      return false;
    });
  }

  void dismissByRequestId(
    String requestId, {
    AppModalResult result = ConfirmResult.dismissed,
  }) {
    if (_current?.request.requestId == requestId) {
      dismissCurrent(result: result);
      return;
    }

    _pending.removeWhere((pending) {
      if (pending.request.requestId == requestId) {
        if (!pending.completer.isCompleted) {
          pending.completer.complete(result);
        }
        return true;
      }
      return false;
    });
    _queue.removeByRequestId(requestId);
  }

  void _activateNext() {
    if (_pending.isEmpty) {
      return;
    }
    final next = _pending.removeAt(0);
    _queue.dequeue();
    _activate(next);
  }

  @override
  void dispose() {
    if (_current != null && !_current!.completer.isCompleted) {
      _current!.completer.complete(ConfirmResult.dismissed);
    }
    for (final pending in _pending) {
      if (!pending.completer.isCompleted) {
        pending.completer.complete(ConfirmResult.dismissed);
      }
    }
    _current = null;
    _pending.clear();
    _queue.clear();
    super.dispose();
  }
}
