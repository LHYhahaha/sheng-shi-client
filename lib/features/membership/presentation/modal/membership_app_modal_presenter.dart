import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_modal_context.dart';
import '../../../../core/modal/app_modal_presenter.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_root_sheet.dart';
import '../../application/membership_controller.dart';
import '../widgets/membership_confirmation_sheet.dart';
import 'membership_modal_channels.dart';
import 'membership_modal_payloads.dart';

/// Membership 购买确认弹窗 presenter。
class MembershipAppModalPresenter implements AppModalPresenter {
  const MembershipAppModalPresenter();

  @override
  bool handles(AppModalRequest request) {
    return request is FeatureAppModalRequest &&
        request.channel == MembershipModalChannels.purchaseConfirmation;
  }

  @override
  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) async {
    final featureRequest = request as FeatureAppModalRequest;
    final payload = featureRequest.payload as MembershipPurchaseModalPayload?;

    if (payload == null) {
      return const MembershipPurchaseModalResult.dismissed();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final container = ProviderScope.containerOf(modalContext, listen: false);

    final status = await showAppModalRootBottomSheet<MembershipPurchaseStatus?>(
      context: modalContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        var didPop = false;
        return UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) {
              ref.listen(
                membershipControllerProvider.select(
                  (state) => state.purchaseStatus,
                ),
                (previous, next) {
                  final reachedTerminalStatus =
                      next == MembershipPurchaseStatus.success ||
                      next == MembershipPurchaseStatus.failed ||
                      next == MembershipPurchaseStatus.cancelled;
                  final shouldCloseForPurchaseFlow =
                      next == MembershipPurchaseStatus.creatingOrder ||
                      next == MembershipPurchaseStatus.waitingPayment ||
                      next == MembershipPurchaseStatus.verifying;
                  if (!didPop &&
                      (reachedTerminalStatus || shouldCloseForPurchaseFlow) &&
                      previous != next) {
                    didPop = true;
                    Navigator.of(sheetContext).pop(next);
                  }
                },
              );

              final sheetState = ref.watch(membershipControllerProvider);
              final sheetController = ref.read(
                membershipControllerProvider.notifier,
              );
              final plan = sheetState.confirmationPlan;
              if (plan == null) {
                return const SizedBox.shrink();
              }
              return MembershipConfirmationSheet(
                plan: plan,
                status: sheetState.purchaseStatus,
                onConfirm: sheetController.confirmPurchase,
                paymentMethods: sheetState.paymentMethods,
                selectedPaymentMethodCode: sheetState.selectedPaymentMethodCode,
                onPaymentMethodSelected: sheetController.selectPaymentMethod,
                onClose: () {
                  Navigator.of(
                    sheetContext,
                  ).pop(ref.read(membershipControllerProvider).purchaseStatus);
                },
              );
            },
          ),
        );
      },
    );
    final finalStatus = _shouldWaitForTerminalStatus(status)
        ? await _waitForTerminalStatus(container)
        : status;
    return switch (finalStatus) {
      MembershipPurchaseStatus.success =>
        const MembershipPurchaseModalResult.completed(),
      MembershipPurchaseStatus.cancelled =>
        const MembershipPurchaseModalResult.cancelled(),
      MembershipPurchaseStatus.failed =>
        const MembershipPurchaseModalResult.failed(),
      null =>
        featureRequest.dismissPolicy.barrierDismissible
            ? const MembershipPurchaseModalResult.dismissed()
            : const MembershipPurchaseModalResult.cancelled(),
      MembershipPurchaseStatus.idle =>
        const MembershipPurchaseModalResult.dismissed(),
      _ => const MembershipPurchaseModalResult.cancelled(),
    };
  }

  Future<MembershipPurchaseStatus?> _waitForTerminalStatus(
    ProviderContainer container,
  ) async {
    final currentStatus = container.read(
      membershipControllerProvider.select((state) => state.purchaseStatus),
    );
    if (_isTerminal(currentStatus)) {
      return currentStatus;
    }

    final completer = Completer<MembershipPurchaseStatus?>();
    late final ProviderSubscription<MembershipPurchaseStatus> subscription;
    subscription = container.listen<MembershipPurchaseStatus>(
      membershipControllerProvider.select((state) => state.purchaseStatus),
      (previous, next) {
        if (_isTerminal(next) && !completer.isCompleted) {
          completer.complete(next);
        }
      },
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => MembershipPurchaseStatus.failed,
      );
    } finally {
      subscription.close();
    }
  }

  bool _isTerminal(MembershipPurchaseStatus status) {
    return status == MembershipPurchaseStatus.success ||
        status == MembershipPurchaseStatus.failed ||
        status == MembershipPurchaseStatus.cancelled;
  }

  bool _shouldWaitForTerminalStatus(MembershipPurchaseStatus? status) {
    return status == MembershipPurchaseStatus.creatingOrder ||
        status == MembershipPurchaseStatus.waitingPayment ||
        status == MembershipPurchaseStatus.verifying;
  }
}
