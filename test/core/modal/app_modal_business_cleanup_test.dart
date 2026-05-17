import 'package:drama_client/core/modal/app_modal_controller.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dismissAllBlockingBusinessModals clears queue without showing next',
    () async {
      final controller = AppModalController();
      addTearDown(controller.dispose);

      ConfirmModalRequest req(String id, AppModalSource source) {
        return ConfirmModalRequest(
          requestId: id,
          source: source,
          title: 't',
          message: 'm',
          confirmLabel: 'OK',
          cancelLabel: 'No',
        );
      }

      final first = controller.present(req('c1', AppModalSource.player));
      final second = controller.present(req('p1', AppModalSource.store));
      final third = controller.present(req('p2', AppModalSource.membership));

      expect(controller.hasCurrent, isTrue);
      expect(controller.queue.length, 2);

      controller.dismissAllBlockingBusinessModals();

      expect(controller.hasCurrent, isFalse);
      expect(controller.queue.isEmpty, isTrue);
      expect(await first, ConfirmResult.dismissed);
      expect(await second, ConfirmResult.dismissed);
      expect(await third, ConfirmResult.dismissed);
    },
  );
}
