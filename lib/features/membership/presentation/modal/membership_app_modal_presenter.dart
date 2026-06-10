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
        return UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) {
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
                onCancel: sheetController.cancelPurchase,
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
    return switch (status) {
      MembershipPurchaseStatus.success =>
        const MembershipPurchaseModalResult.completed(),
      MembershipPurchaseStatus.cancelled =>
        const MembershipPurchaseModalResult.cancelled(),
      null =>
        featureRequest.dismissPolicy.barrierDismissible
            ? const MembershipPurchaseModalResult.dismissed()
            : const MembershipPurchaseModalResult.cancelled(),
      _ => const MembershipPurchaseModalResult.cancelled(),
    };
  }
}
