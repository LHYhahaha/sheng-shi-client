import 'package:drama_client/core/modal/app_modal_controller.dart';
import 'package:drama_client/core/modal/app_modal_observer.dart';
import 'package:drama_client/core/modal/app_modal_policy.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_runtime_config.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recording_app_modal_observer.dart';

void main() {
  group('AppModalController queue', () {
    late RecordingAppModalObserver observer;
    late AppModalController controller;

    ConfirmModalRequest request(
      String id, {
      AppModalPriority priority = AppModalPriority.normal,
      DateTime? createdAt,
    }) {
      return ConfirmModalRequest(
        requestId: id,
        source: AppModalSource.player,
        priority: priority,
        createdAt: createdAt ?? DateTime.now(),
        title: 'Title',
        message: 'Message',
        confirmLabel: 'OK',
        cancelLabel: 'Cancel',
      );
    }

    setUp(() {
      observer = RecordingAppModalObserver();
      controller = AppModalController(
        observer: observer,
        runtimeConfig: const AppModalRuntimeConfig(
          enableModalDiagnostics: true,
          maxQueueLength: 3,
        ),
      );
    });

    tearDown(() => controller.dispose());

    test('does not interrupt current for higher priority pending', () async {
      final first = controller.present(
        request('low', priority: AppModalPriority.low),
      );
      expect(controller.current!.request.requestId, 'low');

      final second = controller.present(
        request('high', priority: AppModalPriority.high),
      );
      expect(controller.current!.request.requestId, 'low');
      expect(controller.queue.pendingRequests.first.requestId, 'high');

      controller.completeCurrent(ConfirmResult.confirmed);
      expect(await first, ConfirmResult.confirmed);
      expect(controller.current!.request.requestId, 'high');

      controller.completeCurrent(ConfirmResult.cancelled);
      expect(await second, ConfirmResult.cancelled);
    });

    test('same priority FIFO in pending', () async {
      final t0 = DateTime(2026, 5, 1, 12);
      final first = controller.present(request('first', createdAt: t0));
      final second = controller.present(
        request('second', createdAt: t0.add(const Duration(seconds: 1))),
      );

      expect(controller.queue.pendingRequests.map((r) => r.requestId), [
        'second',
      ]);

      controller.completeCurrent(ConfirmResult.confirmed);
      await first;
      expect(controller.current!.request.requestId, 'second');

      controller.completeCurrent(ConfirmResult.dismissed);
      expect(await second, ConfirmResult.dismissed);
    });

    test('dismissForSource clears current and pending', () async {
      final current = controller.present(request('current'));
      final pending = controller.present(request('pending'));

      controller.dismissForSource(AppModalSource.player);

      expect(controller.hasCurrent, isFalse);
      expect(await current, ConfirmResult.dismissed);
      expect(await pending, ConfirmResult.dismissed);
      expect(
        observer.events.any((e) => e.kind == AppModalObserverEventKind.queued),
        isTrue,
      );
    });

    test('dismissByRequestId handles current and pending', () async {
      controller.present(request('current'));
      final pendingFuture = controller.present(request('pending'));

      controller.dismissByRequestId('pending');
      expect(await pendingFuture, ConfirmResult.dismissed);
      expect(controller.current!.request.requestId, 'current');

      controller.dismissByRequestId('current');
      expect(controller.hasCurrent, isFalse);
    });

    test('rejects when pending exceeds maxQueueLength', () async {
      controller.present(request('current'));
      controller.present(request('p1'));
      controller.present(request('p2'));
      controller.present(request('p3'));

      final rejected = controller.present(request('overflow'));
      expect(
        await rejected,
        isA<AppModalRejectedResult>().having(
          (r) => r.reason,
          'reason',
          AppModalRejectReason.queueFull,
        ),
      );
      expect(
        observer.events.where(
          (e) => e.kind == AppModalObserverEventKind.queueRejected,
        ),
        isNotEmpty,
      );
    });

    test('system disabled returns rejected without queueing', () async {
      controller.dispose();
      controller = AppModalController(
        observer: observer,
        runtimeConfig: const AppModalRuntimeConfig(
          enableGlobalModalSystem: false,
          enableModalDiagnostics: true,
        ),
      );
      final result = await controller.present(request('blocked'));
      expect(
        result,
        isA<AppModalRejectedResult>().having(
          (r) => r.reason,
          'reason',
          AppModalRejectReason.systemDisabled,
        ),
      );
      expect(controller.hasCurrent, isFalse);
    });

    test(
      'failCurrentPresentation advances queue and logs failedToPresent',
      () async {
        controller.present(request('current'));
        final next = controller.present(request('next'));

        controller.failCurrentPresentation();
        expect(controller.current!.request.requestId, 'next');
        expect(
          observer.events.any(
            (e) =>
                e.kind == AppModalObserverEventKind.failedToPresent &&
                e.requestId == 'current',
          ),
          isTrue,
        );

        controller.completeCurrent(ConfirmResult.confirmed);
        expect(await next, ConfirmResult.confirmed);
      },
    );

    test('records presented and completed with elapsedMs', () {
      controller.present(request('only'));
      controller.markPresented('only');
      controller.completeCurrent(ConfirmResult.confirmed);

      expect(
        observer.events.map((e) => e.kind),
        containsAll([
          AppModalObserverEventKind.presented,
          AppModalObserverEventKind.completed,
        ]),
      );
      final completed = observer.events.lastWhere(
        (e) => e.kind == AppModalObserverEventKind.completed,
      );
      expect(completed.elapsedMs, isNotNull);
      expect(completed.resultKind, AppModalResultKind.completed);
    });
  });
}
