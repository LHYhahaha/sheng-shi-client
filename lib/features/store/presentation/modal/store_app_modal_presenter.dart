import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_modal_context.dart';
import '../../../../core/modal/app_modal_presenter.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_root_sheet.dart';
import '../../application/store_controller.dart';
import '../widgets/store_confirmation_sheet.dart';
import 'store_modal_channels.dart';
import 'store_modal_payloads.dart';

/// Store 购买确认弹窗 presenter：root bottom sheet + 复用 [StoreConfirmationSheet]。
class StoreAppModalPresenter implements AppModalPresenter {
  const StoreAppModalPresenter();

  @override
  bool handles(AppModalRequest request) {
    return request is FeatureAppModalRequest &&
        request.channel == StoreModalChannels.purchaseConfirmation;
  }

  @override
  Future<AppModalResult> present({
    required BuildContext context,
    required AppModalRequest request,
  }) async {
    final featureRequest = request as FeatureAppModalRequest;
    final payload = featureRequest.payload as StorePurchaseModalPayload?;

    if (payload == null) {
      return const StorePurchaseModalResult.dismissed();
    }

    final modalContext = resolveAppModalPresentationContext(context);
    final container = ProviderScope.containerOf(modalContext, listen: false);

    final status = await showAppModalRootBottomSheet<StorePurchaseStatus?>(
      context: modalContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) {
              ref.listen(
                storeControllerProvider.select((state) => state.purchaseStatus),
                (previous, next) {
                  if (next == StorePurchaseStatus.success &&
                      previous != StorePurchaseStatus.success) {
                    Navigator.of(sheetContext).pop(next);
                  }
                },
              );

              final sheetState = ref.watch(storeControllerProvider);
              final sheetController = ref.read(
                storeControllerProvider.notifier,
              );
              final package = sheetState.confirmationPackage;
              if (package == null) {
                return const SizedBox.shrink();
              }
              return StoreConfirmationSheet(
                package: package,
                status: sheetState.purchaseStatus,
                onConfirm: sheetController.confirmPurchase,
                onClose: () {
                  Navigator.of(
                    sheetContext,
                  ).pop(ref.read(storeControllerProvider).purchaseStatus);
                },
              );
            },
          ),
        );
      },
    );
    return switch (status) {
      StorePurchaseStatus.success => const StorePurchaseModalResult.completed(),
      StorePurchaseStatus.failed => const StorePurchaseModalResult.cancelled(),
      StorePurchaseStatus.cancelled =>
        const StorePurchaseModalResult.cancelled(),
      null =>
        featureRequest.dismissPolicy.barrierDismissible
            ? const StorePurchaseModalResult.dismissed()
            : const StorePurchaseModalResult.cancelled(),
      _ => const StorePurchaseModalResult.cancelled(),
    };
  }
}
