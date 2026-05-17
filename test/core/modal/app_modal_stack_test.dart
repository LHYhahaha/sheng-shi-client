import 'package:drama_client/core/modal/app_modal_controller.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stackOnCurrent presents without queueing behind current', () async {
    final controller = AppModalController();
    addTearDown(controller.dispose);

    final base = controller.present(
      ConfirmModalRequest(
        requestId: 'base',
        source: AppModalSource.player,
        title: 'Base',
        message: 'Message',
        confirmLabel: 'OK',
        cancelLabel: 'No',
      ),
    );
    expect(controller.current!.request.requestId, 'base');
    expect(controller.queue.isEmpty, isTrue);

    final stacked = controller.present(
      FeatureAppModalRequest(
        requestId: 'payment',
        source: AppModalSource.player,
        channel: 'player.payment_method',
        stackOnCurrent: true,
        type: AppModalType.paymentConfirm,
      ),
    );

    expect(controller.current!.request.requestId, 'base');
    expect(controller.stackedPresentations.length, 1);
    expect(controller.stackedPresentations.first.request.requestId, 'payment');
    expect(controller.queue.isEmpty, isTrue);

    controller.completePresentation(
      'payment',
      const PaymentModalResult.completed(),
    );
    expect(await stacked, const PaymentModalResult.completed());
    expect(controller.stackedPresentations, isEmpty);
    expect(controller.current!.request.requestId, 'base');

    controller.completeCurrent(ConfirmResult.confirmed);
    expect(await base, ConfirmResult.confirmed);
  });

  test('dismissForSource clears stacked presentations for source', () async {
    final controller = AppModalController();
    addTearDown(controller.dispose);

    controller.present(
      ConfirmModalRequest(
        requestId: 'base',
        source: AppModalSource.player,
        title: 'Base',
        message: 'Message',
        confirmLabel: 'OK',
        cancelLabel: 'No',
      ),
    );
    final stacked = controller.present(
      FeatureAppModalRequest(
        requestId: 'payment',
        source: AppModalSource.player,
        channel: 'player.payment_method',
        stackOnCurrent: true,
      ),
    );

    controller.dismissForSource(AppModalSource.player);

    expect(await stacked, ConfirmResult.dismissed);
    expect(controller.stackedPresentations, isEmpty);
    expect(controller.hasCurrent, isFalse);
  });
}
