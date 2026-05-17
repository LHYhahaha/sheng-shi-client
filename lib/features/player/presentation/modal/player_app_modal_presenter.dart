import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_modal_context.dart';
import '../../../../core/modal/app_modal_presenter.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_root_sheet.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_payment_method_modal_layer.dart';
import '../widgets/player_recharge_unlock_sheet.dart';
import 'player_modal_channels.dart';
import 'player_modal_payloads.dart';

/// Player 解锁/充值弹窗 presenter：通过 root bottom sheet 展示，避免 tab 遮挡。
class PlayerAppModalPresenter implements AppModalPresenter {
  const PlayerAppModalPresenter();

  @override
  bool handles(AppModalRequest request) {
    return request is FeatureAppModalRequest &&
        (request.channel == PlayerModalChannels.coinUnlock ||
            request.channel == PlayerModalChannels.rechargeUnlock ||
            request.channel == PlayerModalChannels.paymentMethod);
  }

  @override
  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) {
    final featureRequest = request as FeatureAppModalRequest;
    return switch (featureRequest.channel) {
      PlayerModalChannels.coinUnlock => _presentCoinUnlock(
        context,
        featureRequest,
      ),
      PlayerModalChannels.rechargeUnlock => _presentRechargeUnlock(
        context,
        featureRequest,
      ),
      PlayerModalChannels.paymentMethod => _presentPaymentMethod(
        context,
        featureRequest,
      ),
      _ => Future.value(ConfirmResult.dismissed),
    };
  }

  Future<AppModalResult> _presentCoinUnlock(
    BuildContext context,
    FeatureAppModalRequest request,
  ) async {
    final payload = request.payload as PlayerCoinUnlockModalPayload?;

    if (payload == null) {
      return const CoinUnlockModalResult.dismissed();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final container = ProviderScope.containerOf(modalContext, listen: false);
    final balance = container.read(entitlementControllerProvider).coinBalance;
    final unlocked = await showAppModalRootBottomSheet<bool>(
      context: modalContext,
      builder: (sheetContext) {
        return PlayerCoinUnlockSheet(
          price: payload.price,
          balance: balance,
          onConfirm: () => Navigator.of(sheetContext).pop(true),
        );
      },
    );

    if (unlocked == true) {
      return const CoinUnlockModalResult.completed();
    }
    if (request.dismissPolicy.barrierDismissible) {
      return const CoinUnlockModalResult.dismissed();
    }
    return const CoinUnlockModalResult.cancelled();
  }

  Future<AppModalResult> _presentRechargeUnlock(
    BuildContext context,
    FeatureAppModalRequest request,
  ) async {
    final payload = request.payload as PlayerRechargeUnlockModalPayload?;

    if (payload == null) {
      return const RechargeModalResult.cancelled();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final unlocked = await showAppModalRootBottomSheet<bool>(
      context: modalContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return PlayerRechargeUnlockSheet(sessionKey: payload.sessionKey);
      },
    );

    if (unlocked == true) {
      return const RechargeModalResult.completed();
    }
    if (request.dismissPolicy.barrierDismissible && unlocked == null) {
      return const RechargeModalResult.cancelled();
    }
    return const RechargeModalResult.cancelled();
  }

  Future<AppModalResult> _presentPaymentMethod(
    BuildContext context,
    FeatureAppModalRequest request,
  ) async {
    final payload = request.payload as PlayerPaymentMethodModalPayload?;

    if (payload == null) {
      return const PaymentModalResult.cancelled();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final purchased = await showGeneralDialog<bool>(
      context: modalContext,
      barrierDismissible: request.dismissPolicy.barrierDismissible,
      barrierLabel: MaterialLocalizations.of(
        modalContext,
      ).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, _) {
        return MediaQuery(
          data: MediaQuery.of(modalContext),
          child: PlayerPaymentMethodModalLayer(
            sessionKey: payload.sessionKey,
            selection: payload.selection,
            onDismissed: () => Navigator.of(dialogContext).pop(false),
            onPurchaseSuccess: () => Navigator.of(dialogContext).pop(true),
          ),
        );
      },
    );

    if (purchased == true) {
      return const PaymentModalResult.completed();
    }
    if (request.dismissPolicy.barrierDismissible && purchased == null) {
      return const PaymentModalResult.dismissed();
    }
    return const PaymentModalResult.cancelled();
  }
}
