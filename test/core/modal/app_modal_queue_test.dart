import 'dart:async';

import 'package:drama_client/core/modal/app_modal_policy.dart';
import 'package:drama_client/core/modal/app_modal_queue.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppModalQueueEntry entry(
    String id, {
    AppModalPriority priority = AppModalPriority.normal,
    DateTime? createdAt,
    AppModalSource source = AppModalSource.system,
  }) {
    return AppModalQueueEntry(
      request: ConfirmModalRequest(
        requestId: id,
        source: source,
        priority: priority,
        createdAt: createdAt ?? DateTime.now(),
        title: 't',
        message: 'm',
        confirmLabel: 'OK',
        cancelLabel: 'Cancel',
      ),
      completer: Completer(),
    );
  }

  test('orders higher priority before lower', () {
    final queue = AppModalQueue();
    final t0 = DateTime(2026, 1, 1);
    queue.insert(entry('low', priority: AppModalPriority.low, createdAt: t0));
    queue.insert(
      entry(
        'high',
        priority: AppModalPriority.high,
        createdAt: t0.add(const Duration(seconds: 1)),
      ),
    );

    expect(queue.pendingRequests.map((r) => r.requestId), ['high', 'low']);
  });

  test('same priority FIFO by createdAt', () {
    final queue = AppModalQueue();
    final t0 = DateTime(2026, 1, 1);
    queue.insert(entry('first', createdAt: t0));
    queue.insert(
      entry('second', createdAt: t0.add(const Duration(seconds: 1))),
    );

    expect(queue.pendingRequests.map((r) => r.requestId), ['first', 'second']);
  });

  test('dequeue returns front in priority order', () {
    final queue = AppModalQueue();
    queue.insert(entry('a', priority: AppModalPriority.normal));
    queue.insert(entry('b', priority: AppModalPriority.critical));
    expect(queue.dequeue()!.request.requestId, 'b');
    expect(queue.dequeue()!.request.requestId, 'a');
    expect(queue.dequeue(), isNull);
  });

  test('removeByRequestId and removeBySource', () {
    final queue = AppModalQueue();
    queue.insert(entry('keep', source: AppModalSource.store));
    queue.insert(entry('drop', source: AppModalSource.player));

    final removed = queue.removeByRequestId('drop');
    expect(removed, hasLength(1));
    expect(queue.pendingRequests.single.requestId, 'keep');

    queue.insert(
      AppModalQueueEntry(
        request: ConfirmModalRequest(
          requestId: 'also_drop',
          source: AppModalSource.store,
          title: 't',
          message: 'm',
          confirmLabel: 'OK',
          cancelLabel: 'Cancel',
        ),
        completer: Completer(),
      ),
    );
    final bySource = queue.removeBySource(AppModalSource.store);
    expect(bySource, hasLength(2));
    expect(queue.isEmpty, isTrue);
  });
}
