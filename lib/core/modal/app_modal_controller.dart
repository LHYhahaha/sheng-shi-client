import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_modal_observer.dart';
import 'app_modal_queue.dart';
import 'app_modal_request.dart';
import 'app_modal_result.dart';
import 'app_modal_runtime_config.dart';
import 'app_modal_source.dart';

/// 当前正在展示的弹窗会话。
class AppModalPresentation {
  AppModalPresentation({
    required this.request,
    required this.completer,
    required this.presentedAt,
  });

  final AppModalRequest request;
  final Completer<AppModalResult> completer;
  final DateTime presentedAt;
}

/// Host 与 Service 之间的协调器：串行展示 + 优先级队列（O5）+ 叠层（O2.1）。
class AppModalController extends ChangeNotifier {
  AppModalController({
    AppModalQueue? queue,
    AppModalObserver? observer,
    AppModalRuntimeConfig? runtimeConfig,
  }) : _queue = queue ?? AppModalQueue(),
       _observer = observer ?? const NoOpAppModalObserver(),
       _runtimeConfig = runtimeConfig ?? AppModalRuntimeConfig.defaults;

  final AppModalQueue _queue;
  final AppModalObserver _observer;
  final AppModalRuntimeConfig _runtimeConfig;

  AppModalPresentation? _current;
  final List<AppModalPresentation> _stacked = [];
  int _requestCounter = 0;

  AppModalQueue get queue => _queue;

  AppModalRuntimeConfig get runtimeConfig => _runtimeConfig;

  AppModalPresentation? get current => _current;

  List<AppModalPresentation> get stackedPresentations =>
      List<AppModalPresentation>.unmodifiable(_stacked);

  bool get hasCurrent => _current != null || _stacked.isNotEmpty;

  String nextRequestId() {
    _requestCounter += 1;
    return 'app_modal_$_requestCounter';
  }

  Future<AppModalResult> present(AppModalRequest request) {
    if (!_runtimeConfig.enableGlobalModalSystem) {
      _emit(
        AppModalObserverEvent(
          kind: AppModalObserverEventKind.queueRejected,
          requestId: request.requestId,
          source: request.source,
          type: request.type,
          priority: request.priority,
          channel: appModalChannelFor(request),
          rejectReason: AppModalRejectReason.systemDisabled.name,
        ),
      );
      return Future<AppModalResult>.value(
        const AppModalRejectedResult(AppModalRejectReason.systemDisabled),
      );
    }

    final completer = Completer<AppModalResult>();
    final presentation = AppModalPresentation(
      request: request,
      completer: completer,
      presentedAt: DateTime.now(),
    );

    if (_shouldStackOnCurrent(request)) {
      _stacked.add(presentation);
      notifyListeners();
      return completer.future;
    }

    final entry = AppModalQueueEntry(request: request, completer: completer);

    if (_current == null) {
      _activate(entry);
    } else {
      if (_queue.length >= _runtimeConfig.maxQueueLength) {
        _emit(
          AppModalObserverEvent(
            kind: AppModalObserverEventKind.queueRejected,
            requestId: request.requestId,
            source: request.source,
            type: request.type,
            priority: request.priority,
            channel: appModalChannelFor(request),
            rejectReason: AppModalRejectReason.queueFull.name,
          ),
        );
        completer.complete(
          const AppModalRejectedResult(AppModalRejectReason.queueFull),
        );
        return completer.future;
      }
      _queue.insert(entry);
      _emitQueued(request);
    }

    return completer.future;
  }

  bool _shouldStackOnCurrent(AppModalRequest request) {
    return _current != null &&
        request is FeatureAppModalRequest &&
        request.stackOnCurrent;
  }

  void markPresented(String requestId) {
    final presentation = _findPresentation(requestId);
    if (presentation == null) {
      return;
    }
    _emit(
      AppModalObserverEvent(
        kind: AppModalObserverEventKind.presented,
        requestId: requestId,
        source: presentation.request.source,
        type: presentation.request.type,
        priority: presentation.request.priority,
        channel: appModalChannelFor(presentation.request),
      ),
    );
  }

  void _activate(AppModalQueueEntry entry) {
    _current = AppModalPresentation(
      request: entry.request,
      completer: entry.completer,
      presentedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void completePresentation(String requestId, AppModalResult result) {
    final stackedIndex = _stacked.indexWhere(
      (presentation) => presentation.request.requestId == requestId,
    );
    if (stackedIndex >= 0) {
      final presentation = _stacked.removeAt(stackedIndex);
      _completePresentation(presentation, result);
      notifyListeners();
      return;
    }
    if (_current?.request.requestId == requestId) {
      completeCurrent(result);
    }
  }

  void completeCurrent(AppModalResult result) {
    final presentation = _current;
    if (presentation == null) {
      return;
    }
    _completePresentation(presentation, result);
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
    final removed = _queue.removeBySource(source);
    for (final entry in removed) {
      _completeEntry(entry, result);
      _emitDismissed(entry.request, result);
    }

    while (_stacked.any(
      (presentation) => presentation.request.source == source,
    )) {
      final index = _stacked.lastIndexWhere(
        (presentation) => presentation.request.source == source,
      );
      final presentation = _stacked.removeAt(index);
      _completePresentation(presentation, result);
      _emitDismissed(presentation.request, result);
    }

    if (_current?.request.source == source) {
      dismissCurrent(result: result);
    }
    notifyListeners();
  }

  /// 清空全部 pending 并关闭 current；**不** dequeue 展示下一项（session cleanup 用）。
  void dismissAllBlockingBusinessModals({
    AppModalResult result = ConfirmResult.dismissed,
  }) {
    while (_queue.isNotEmpty) {
      final entry = _queue.dequeue()!;
      _completeEntry(entry, result);
      _emitDismissed(entry.request, result);
    }

    while (_stacked.isNotEmpty) {
      final presentation = _stacked.removeLast();
      _completePresentation(presentation, result);
      _emitDismissed(presentation.request, result);
    }

    final presentation = _current;
    if (presentation == null) {
      notifyListeners();
      return;
    }
    _completePresentation(presentation, result);
    _current = null;
    notifyListeners();
  }

  void dismissByRequestId(
    String requestId, {
    AppModalResult result = ConfirmResult.dismissed,
  }) {
    final stackedIndex = _stacked.indexWhere(
      (presentation) => presentation.request.requestId == requestId,
    );
    if (stackedIndex >= 0) {
      final presentation = _stacked.removeAt(stackedIndex);
      _completePresentation(presentation, result);
      _emitDismissed(presentation.request, result);
      notifyListeners();
      return;
    }

    if (_current?.request.requestId == requestId) {
      dismissCurrent(result: result);
      return;
    }

    final removed = _queue.removeByRequestId(requestId);
    for (final entry in removed) {
      _completeEntry(entry, result);
      _emitDismissed(entry.request, result);
    }
  }

  void failCurrentPresentation() {
    completeCurrent(const AppModalPresentFailedResult());
  }

  void _activateNext() {
    final next = _queue.dequeue();
    if (next == null) {
      return;
    }
    _activate(next);
  }

  bool containsPresentation(String requestId) {
    return _findPresentation(requestId) != null;
  }

  AppModalPresentation? _findPresentation(String requestId) {
    if (_current?.request.requestId == requestId) {
      return _current;
    }
    for (final presentation in _stacked) {
      if (presentation.request.requestId == requestId) {
        return presentation;
      }
    }
    return null;
  }

  void _completePresentation(
    AppModalPresentation presentation,
    AppModalResult result,
  ) {
    if (!presentation.completer.isCompleted) {
      presentation.completer.complete(result);
    }
    final elapsedMs = DateTime.now()
        .difference(presentation.presentedAt)
        .inMilliseconds;
    _emitCompleted(presentation.request, result, elapsedMs);
  }

  void _completeEntry(AppModalQueueEntry entry, AppModalResult result) {
    if (!entry.completer.isCompleted) {
      entry.completer.complete(result);
    }
  }

  void _emitQueued(AppModalRequest request) {
    _emit(
      AppModalObserverEvent(
        kind: AppModalObserverEventKind.queued,
        requestId: request.requestId,
        source: request.source,
        type: request.type,
        priority: request.priority,
        channel: appModalChannelFor(request),
      ),
    );
  }

  void _emitCompleted(
    AppModalRequest request,
    AppModalResult result,
    int elapsedMs,
  ) {
    final kind = switch (result.kind) {
      AppModalResultKind.completed => AppModalObserverEventKind.completed,
      AppModalResultKind.cancelled => AppModalObserverEventKind.cancelled,
      AppModalResultKind.dismissed => AppModalObserverEventKind.dismissed,
      AppModalResultKind.failed =>
        result is AppModalPresentFailedResult
            ? AppModalObserverEventKind.failedToPresent
            : AppModalObserverEventKind.dismissed,
    };
    _emit(
      AppModalObserverEvent(
        kind: kind,
        requestId: request.requestId,
        source: request.source,
        type: request.type,
        priority: request.priority,
        channel: appModalChannelFor(request),
        resultKind: result.kind,
        elapsedMs: elapsedMs,
      ),
    );
  }

  void _emitDismissed(AppModalRequest request, AppModalResult result) {
    _emit(
      AppModalObserverEvent(
        kind: AppModalObserverEventKind.dismissed,
        requestId: request.requestId,
        source: request.source,
        type: request.type,
        priority: request.priority,
        channel: appModalChannelFor(request),
        resultKind: result.kind,
      ),
    );
  }

  void _emit(AppModalObserverEvent event) {
    if (!_runtimeConfig.enableModalDiagnostics) {
      return;
    }
    _observer.onEvent(event);
  }

  @override
  void dispose() {
    if (_current != null) {
      _completePresentation(_current!, ConfirmResult.dismissed);
      _current = null;
    }
    while (_stacked.isNotEmpty) {
      final presentation = _stacked.removeLast();
      _completePresentation(presentation, ConfirmResult.dismissed);
    }
    while (_queue.isNotEmpty) {
      final entry = _queue.dequeue()!;
      _completeEntry(entry, ConfirmResult.dismissed);
    }
    super.dispose();
  }
}
