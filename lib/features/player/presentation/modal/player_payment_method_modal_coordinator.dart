import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/modal/app_modal_controller.dart';
import '../../../../core/modal/app_modal_policy.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../widgets/player_payment_method_sheet.dart';
import 'player_modal_channels.dart';
import 'player_modal_payloads.dart';

/// 从充值大抽屉内唤起 Payment Method（叠在当前 AppModal 之上）。
class PlayerPaymentMethodModalCoordinator {
  PlayerPaymentMethodModalCoordinator({
    required AppModalService modalService,
    required AppModalController modalController,
  }) : _modalService = modalService,
       _modalController = modalController;

  final AppModalService _modalService;
  final AppModalController _modalController;

  Future<PaymentModalResult> showPaymentMethod({
    required String sessionKey,
    required PlayerPaymentSelection selection,
  }) {
    final result = _modalService.show(
      FeatureAppModalRequest(
        requestId: _modalController.nextRequestId(),
        source: AppModalSource.player,
        channel: PlayerModalChannels.paymentMethod,
        payload: PlayerPaymentMethodModalPayload(
          sessionKey: sessionKey,
          selection: selection,
        ),
        type: AppModalType.paymentConfirm,
        priority: AppModalPriority.high,
        dismissPolicy: AppModalDismissPolicy.standard,
        stackOnCurrent: true,
      ),
    );
    return result.then(_asPaymentResult);
  }

  PaymentModalResult _asPaymentResult(AppModalResult result) {
    if (result is PaymentModalResult) {
      return result;
    }
    return switch (result.kind) {
      AppModalResultKind.completed => const PaymentModalResult.completed(),
      AppModalResultKind.cancelled => const PaymentModalResult.cancelled(),
      AppModalResultKind.dismissed => const PaymentModalResult.dismissed(),
      AppModalResultKind.failed => const PaymentModalResult.failed(),
    };
  }
}

final playerPaymentMethodModalCoordinatorProvider =
    Provider.family<PlayerPaymentMethodModalCoordinator, String>((
      ref,
      sessionKey,
    ) {
      return PlayerPaymentMethodModalCoordinator(
        modalService: ref.watch(appModalServiceProvider),
        modalController: ref.watch(appModalControllerProvider),
      );
    });
